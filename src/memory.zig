const builtin = @import("builtin");
const std = @import("std");

const config = @import("config.zig");
const value = @import("value.zig");
const domain = @import("domain.zig");
const minor_gc = @import("minor_gc.zig");
const major_gc = @import("major_gc.zig");
const shared_heap = @import("shared_heap.zig");
const fail = @import("fail.zig");
const signal = @import("signal.zig");
const event = @import("event.zig");
const misc = @import("misc.zig");

pub export fn clear(res: value.Value, wsz: usize) void {
    if (builtin.mode == .Debug) {
        for (0..wsz) |i| {
            std.debug.assert(value.field(res, i) == misc.debug.free_minor);
            value.fieldPtr(res, i).* = misc.debug.uninit_minor;
        }
    }
}

pub const AllocSmallFlags =
    usize;
pub const alloc_small_flags = struct {
    pub export const dont_track: AllocSmallFlags =
        0;
    pub export const do_track: AllocSmallFlags =
        1;
    pub export const from_c: AllocSmallFlags =
        0;
    pub export const from_ocaml: AllocSmallFlags =
        2;
};

pub fn allocSmallGcFlags(state: *domain.State, wsz: usize, flags: AllocSmallFlags) void {
    minor_gc.allocSmallDispatch(state, wsz, flags);
}
pub fn allocSmallGc(state: *domain.State, wsz: usize, _: void) void {
    allocSmallGcFlags(state, wsz, alloc_small_flags.dont_track | alloc_small_flags.from_c);
}

pub fn allocSmallWithReserved(wsz: usize, tag: value.Tag, rsv: value.Reserved, comptime GcData: type, gc: *const fn (*domain.State, usize, GcData) void, gc_data: GcData) value.Value {
    std.debug.assert(1 <= wsz);
    std.debug.assert(tag <= value.tag_max);
    std.debug.assert(wsz <= config.max_young_wsize);
    const state = domain.state.?;
    state.young_ptr -= wsz + value.header_wsize;
    if (domain.checkGcInterrupt(state)) {
        gc(state, wsz, gc_data);
    }
    const hdr = @as(*value.Header, @ptrCast(state.young_ptr));
    hdr.* = value.headerMakeWithReserved(wsz, tag, 0, rsv);
    const res = value.ofHeaderPtr(hdr);
    clear(res, wsz);
    return res;
}
pub fn allocSmall(wsz: usize, tag: value.Tag, comptime GcData: type, gc: *const fn (*domain.State, usize, GcData) void, gc_data: GcData) value.Value {
    return allocSmallWithReserved(wsz, tag, 0, GcData, gc, gc_data);
}

pub const Roots = struct {
    next: ?*const Roots,
    num_table: usize,
    num_item: usize,
    tables: [5][*]const value.Value,

    const Self = @This();

    pub fn make1(val1: *const value.Value) Self {
        return .{
            .next = domain.state.?.local_roots,
            .num_table = 1,
            .num_item = 1,
            .tables = [5][*]const value.Value{ @ptrCast(val1), undefined, undefined, undefined, undefined },
        };
    }
    pub fn make2(val1: *const value.Value, val2: *const value.Value) Self {
        return .{
            .next = domain.state.?.local_roots,
            .num_table = 2,
            .num_item = 1,
            .tables = [5][*]const value.Value{ @ptrCast(val1), @ptrCast(val2), undefined, undefined, undefined },
        };
    }
    pub fn make3(val1: *const value.Value, val2: *const value.Value, val3: *const value.Value) Self {
        return .{
            .next = domain.state.?.local_roots,
            .num_table = 3,
            .num_item = 1,
            .tables = [5][*]const value.Value{ @ptrCast(val1), @ptrCast(val2), @ptrCast(val3), undefined, undefined },
        };
    }
    pub fn make4(val1: *const value.Value, val2: *const value.Value, val3: *const value.Value, val4: *const value.Value) Self {
        return .{
            .next = domain.state.?.local_roots,
            .num_table = 4,
            .num_item = 1,
            .tables = [5][*]const value.Value{ @ptrCast(val1), @ptrCast(val2), @ptrCast(val3), @ptrCast(val4), undefined },
        };
    }
    pub fn make5(val1: *const value.Value, val2: *const value.Value, val3: *const value.Value, val4: *const value.Value, val5: *const value.Value) Self {
        return .{
            .next = domain.state.?.local_roots,
            .num_table = 5,
            .num_item = 1,
            .tables = [5][*]const value.Value{ @ptrCast(val1), @ptrCast(val2), @ptrCast(val3), @ptrCast(val4), @ptrCast(val5) },
        };
    }
    pub fn make(vals: [*]const value.Value, sz: usize) Self {
        return .{
            .next = domain.state.?.local_roots,
            .num_table = 1,
            .num_item = sz,
            .tables = [5][*]const value.Value{ vals, undefined, undefined, undefined, undefined },
        };
    }
};

pub const Frame = struct {
    roots: ?*const Roots,

    const Self = @This();

    pub fn create() Self {
        return .{ .roots = domain.state.?.local_roots };
    }
    pub fn destroy(self: Self) void {
        domain.state.?.local_roots = self.roots;
    }
    pub fn add(self: *const Self, roots: *const Roots) void {
        _ = self;
        domain.state.?.local_roots = roots;
    }
};

pub export fn writeBarrier(blk: value.Value, i: usize, old_val: value.Value, new_val: value.Value) void {
    std.debug.assert(value.isBlock(blk));
    if (!value.isYoung(blk)) {
        if (value.isBlock(old_val)) {
            if (value.isYoung(old_val)) {
                return;
            }
            major_gc.darken(domain.state.?, old_val, null);
        }
        if (value.isBlock(new_val) and value.isYoung(new_val)) {
            domain.state.?.minor_tables.value_table.add(value.fieldPtr(blk, i));
        }
    }
}

pub fn setField(blk: value.Value, i: usize, val: value.Value) void {
    const fld = value.fieldPtr(blk, i);
    writeBarrier(blk, i, @atomicLoad(value.Value, fld, .Unordered), val);
    @fence(.Acquire);
    @atomicStore(value.Value, fld, val, .Release);
}
pub fn setFields(blk: value.Value, val: value.Value) void {
    std.debug.assert(value.isBlock(blk));
    for (0..value.size(blk)) |i| {
        setField(blk, i, val);
    }
}

pub export fn initialize(blk: value.Value, i: usize, val: value.Value) void {
    const fld = value.fieldPtr(blk, i);
    std.debug.assert(value.isInt(@atomicLoad(value.Value, fld, .Unordered)));
    @atomicStore(value.Value, fld, val, .Unordered);
    if (!value.isYoung(blk) and value.isBlock(val) and value.isYoung(val)) {
        domain.state.?.minor_tables.value_table.add(fld);
    }
}

pub export fn atomicCas(blk: value.Value, i: usize, old_val: value.Value, new_val: value.Value) bool {
    const fld = value.fieldPtr(blk, i);
    if (domain.alone()) {
        if (@atomicLoad(value.Value, fld, .Unordered) == old_val) {
            @atomicStore(value.Value, fld, new_val, .Unordered);
            writeBarrier(blk, i, old_val, new_val);
            return true;
        } else {
            return false;
        }
    } else {
        const res = @cmpxchgStrong(value.Value, fld, old_val, new_val, .SeqCst, .SeqCst);
        @fence(.Release);
        if (res) |_| {
            return false;
        } else {
            writeBarrier(blk, i, old_val, new_val);
            return true;
        }
    }
}

pub export fn atomicLoad(blk: value.Value, i: usize) value.Value {
    const fld = value.fieldPtr(blk, i);
    if (domain.alone()) {
        return @atomicLoad(value.Value, fld, .Unordered);
    } else {
        @fence(.Acquire);
        return @atomicLoad(value.Value, fld, .SeqCst);
    }
}

pub export fn atomicExchange(blk: value.Value, i: usize, val: value.Value) value.Value {
    const fld = value.fieldPtr(blk, i);
    var res: value.Value = undefined;
    if (domain.alone()) {
        res = @atomicLoad(value.Value, fld, .Unordered);
        @atomicStore(value.Value, fld, val, .Unordered);
    } else {
        @fence(.Acquire);
        res = @atomicRmw(value.Value, fld, .Xchg, val, .SeqCst);
        @fence(.Release);
    }
    writeBarrier(blk, i, res, val);
    return res;
}

pub export fn atomicFetchAdd(blk: value.Value, i: usize, incr: value.Value) value.Value {
    const fld = value.fieldPtr(blk, i);
    var res: value.Value = undefined;
    if (domain.alone()) {
        res = @atomicLoad(value.Value, fld, .Unordered);
        @atomicStore(value.Value, fld, value.ofInt(value.toInt(res) + value.toInt(incr)), .Unordered);
    } else {
        res = @atomicRmw(value.Value, fld, .Add, value.toInt(incr) * 2, .SeqCst);
        @fence(.Release);
    }
    return res;
}

pub export fn allocShared(wsz: usize, tag: value.Tag, rsv: value.Reserved) value.Value {
    domain.checkState();
    const state = domain.state.?;
    if (shared_heap.tryAllocShared(state.shared_heap, wsz, tag, rsv, false)) |blk| {
        state.allocated_words += wsz + value.header_wsize;
        if (state.minor_heap_wsize / 5 < state.allocated_words) {
            event.counter(.request_major_alloc_shared, 1);
            signal.requestMajorSlice(true);
        }
        if (builtin.mode == .Debug and tag < value.tag_no_scan) {
            for (0..wsz) |i| {
                value.fieldPtr(blk, i).* = misc.debug.uninit_major;
            }
        }
        return blk;
    } else {
        fail.raiseOutOfMemory();
    }
}

pub const static = struct {
    const Block = struct {
        const Self = @This();

        next: ?*Self,
        prev: *Self,
        data: void align(@max(@alignOf(usize), @max(@alignOf(f32), @max(@alignOf(f64), @max(@alignOf(*anyopaque), @alignOf(*const fn () void)))))) = {},

        pub var pool: ?*Self =
            null;
        pub var mutex =
            std.Thread.Mutex{};

        pub fn get(data: anytype) *Self {
            _ = @typeInfo(@TypeOf(data)).Pointer;
            return @ptrCast(@as([*]Self, @ptrCast(data)) - 1);
        }

        pub fn dataAs(self: *Self, comptime T: type) [*]T {
            return @ptrCast(&self.data);
        }

        pub fn link(self: *Self) void {
            mutex.lock();
            defer mutex.unlock();

            self.next = pool.?.next.?;
            self.prev = pool.?;
            pool.?.next.?.prev = self;
            pool.?.next = self;
        }
        pub fn unlink(self: *Self) void {
            mutex.lock();
            defer mutex.unlock();

            self.prev.next = self.next.?;
            self.next.?.prev = self.prev;
        }
    };

    pub export fn create() void {
        if (Block.pool == null) {
            if (@as(?*Block, @ptrCast(@alignCast(std.c.malloc(@sizeOf(Block)))))) |blk| {
                Block.pool = blk;
                Block.pool.?.next = blk;
                Block.pool.?.prev = blk;
            } else {
                misc.fatalError("Fatal error: out of memory.\n");
            }
        }
    }

    pub export fn destroy() void {
        Block.mutex.lock();
        defer Block.mutex.unlock();

        if (Block.pool) |pool| {
            pool.prev.next = null;
            while (Block.pool) |pool_| {
                const next = pool_.next;
                std.c.free(Block.pool);
                Block.pool = next;
            }
            Block.pool = null;
        }
    }

    pub fn allocNoexc(comptime T: type, sz: usize) ?[*]T {
        if (Block.pool) |_| {
            if (@as(?*Block, @ptrCast(@alignCast(std.c.malloc(@sizeOf(Block) + sz * @sizeOf(T)))))) |blk| {
                blk.link();
                return blk.dataAs(T);
            } else {
                return null;
            }
        } else {
            return @ptrCast(@alignCast(std.c.malloc(sz * @sizeOf(T))));
        }
    }
    pub fn alloc1Noexc(comptime T: type) ?*T {
        return allocNoexc(T, 1);
    }

    pub fn free(data: anytype) void {
        if (Block.pool) |_| {
            if (data) |data_| {
                const blk = Block.get(data_);
                blk.unlink();
                std.c.free(blk);
            } else {
                return;
            }
        } else {
            std.c.free(@ptrCast(data));
        }
    }

    pub fn resizeNoexc(comptime T: type, data: ?[*]T, sz: usize) ?[*]T {
        if (data) |data_| {
            if (Block.pool) |_| {
                const blk = Block.get(data_);
                blk.unlink();
                if (@as(?*Block, @ptrCast(@alignCast(std.c.realloc(blk, @sizeOf(Block) + sz * @sizeOf(T)))))) |new_blk| {
                    new_blk.link();
                    return new_blk.dataAs(T);
                } else {
                    blk.link();
                    return null;
                }
            } else {
                return @ptrCast(@alignCast(std.c.realloc(@ptrCast(data), sz)));
            }
        } else {
            return allocNoexc(T, sz);
        }
    }
    pub fn resize(comptime T: type, data: ?[*]T, sz: usize) [*]T {
        if (resizeNoexc(T, data, sz)) |res| {
            return res;
        } else {
            fail.raiseOutOfMemory();
        }
    }
};
