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

comptime {
    @export(clear, .{ .name = "caml_memory_clear" });
    @export(alloc_small_flags.dont_track, .{ .name = "caml_memory_dont_track" });
    @export(alloc_small_flags.do_track, .{ .name = "caml_memory_do_track" });
    @export(alloc_small_flags.from_c, .{ .name = "caml_memory_from_c" });
    @export(alloc_small_flags.from_ocaml, .{ .name = "caml_memory_from_ocaml" });
    @export(writeBarrier, .{ .name = "caml_memory_write_barrier" });
    @export(setField, .{ .name = "caml_memory_set_field" });
    @export(setFields, .{ .name = "caml_memory_set_fields" });
    @export(initialize, .{ .name = "caml_memory_initialize" });
    @export(atomicCas, .{ .name = "caml_memory_atomic_cas" });
    @export(atomicLoad, .{ .name = "caml_memory_atomic_load" });
    @export(atomicExchange, .{ .name = "caml_memory_atomic_exchange" });
    @export(atomicFetchAdd, .{ .name = "caml_memory_atomic_fetch_add" });
    @export(allocShared, .{ .name = "caml_memory_alloc_shared" });
    @export(registerGenerationalGlobalRoot, .{ .name = "caml_memory_register_generational_global_root" });
    @export(modifyGenerationalGlobalRoot, .{ .name = "caml_memory_modify_generational_global_root" });
}

pub fn clear(res: value.Value, wsz: usize) callconv(.C) void {
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
    pub const dont_track: AllocSmallFlags =
        0;
    pub const do_track: AllocSmallFlags =
        1;
    pub const from_c: AllocSmallFlags =
        0;
    pub const from_ocaml: AllocSmallFlags =
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

    pub fn make1(v1: *const value.Value) Self {
        return .{
            .next = domain.state.?.local_roots,
            .num_table = 1,
            .num_item = 1,
            .tables = [5][*]const value.Value{ @ptrCast(v1), undefined, undefined, undefined, undefined },
        };
    }
    pub fn make2(v1: *const value.Value, v2: *const value.Value) Self {
        return .{
            .next = domain.state.?.local_roots,
            .num_table = 2,
            .num_item = 1,
            .tables = [5][*]const value.Value{ @ptrCast(v1), @ptrCast(v2), undefined, undefined, undefined },
        };
    }
    pub fn make3(v1: *const value.Value, v2: *const value.Value, v3: *const value.Value) Self {
        return .{
            .next = domain.state.?.local_roots,
            .num_table = 3,
            .num_item = 1,
            .tables = [5][*]const value.Value{ @ptrCast(v1), @ptrCast(v2), @ptrCast(v3), undefined, undefined },
        };
    }
    pub fn make4(v1: *const value.Value, v2: *const value.Value, v3: *const value.Value, v4: *const value.Value) Self {
        return .{
            .next = domain.state.?.local_roots,
            .num_table = 4,
            .num_item = 1,
            .tables = [5][*]const value.Value{ @ptrCast(v1), @ptrCast(v2), @ptrCast(v3), @ptrCast(v4), undefined },
        };
    }
    pub fn make5(v1: *const value.Value, v2: *const value.Value, v3: *const value.Value, v4: *const value.Value, v5: *const value.Value) Self {
        return .{
            .next = domain.state.?.local_roots,
            .num_table = 5,
            .num_item = 1,
            .tables = [5][*]const value.Value{ @ptrCast(v1), @ptrCast(v2), @ptrCast(v3), @ptrCast(v4), @ptrCast(v5) },
        };
    }
    pub fn make(vs: [*]const value.Value, sz: usize) Self {
        return .{
            .next = domain.state.?.local_roots,
            .num_table = 1,
            .num_item = sz,
            .tables = [5][*]const value.Value{ vs, undefined, undefined, undefined, undefined },
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

pub fn writeBarrier(blk: value.Value, i: usize, v_old: value.Value, v_new: value.Value) callconv(.C) void {
    std.debug.assert(value.isBlock(blk));
    if (!value.isYoung(blk)) {
        if (value.isBlock(v_old)) {
            if (value.isYoung(v_old)) {
                return;
            }
            major_gc.darken(domain.state.?, v_old, null);
        }
        if (value.isBlock(v_new) and value.isYoung(v_new)) {
            domain.state.?.minor_tables.value_table.add(value.fieldPtr(blk, i));
        }
    }
}

pub fn setField(blk: value.Value, i: usize, v: value.Value) callconv(.C) void {
    const fld = value.fieldPtr(blk, i);
    writeBarrier(blk, i, @atomicLoad(value.Value, fld, .Monotonic), v);
    @fence(.Acquire);
    @atomicStore(value.Value, fld, v, .Release);
}
pub fn setFields(blk: value.Value, v: value.Value) callconv(.C) void {
    std.debug.assert(value.isBlock(blk));
    for (0..value.size(blk)) |i| {
        setField(blk, i, v);
    }
}

pub fn initialize(blk: value.Value, i: usize, v: value.Value) callconv(.C) void {
    const fld = value.fieldPtr(blk, i);
    std.debug.assert(value.isInt(@atomicLoad(value.Value, fld, .Monotonic)));
    @atomicStore(value.Value, fld, v, .Monotonic);
    if (!value.isYoung(blk) and value.isBlock(v) and value.isYoung(v)) {
        domain.state.?.minor_tables.value_table.add(fld);
    }
}

pub fn atomicCas(blk: value.Value, i: usize, v_old: value.Value, v_new: value.Value) callconv(.C) bool {
    const fld = value.fieldPtr(blk, i);
    if (domain.alone()) {
        if (@atomicLoad(value.Value, fld, .Monotonic) == v_old) {
            @atomicStore(value.Value, fld, v_new, .Monotonic);
            writeBarrier(blk, i, v_old, v_new);
            return true;
        } else {
            return false;
        }
    } else {
        const res = @cmpxchgStrong(value.Value, fld, v_old, v_new, .SeqCst, .SeqCst);
        @fence(.Release);
        if (res) |_| {
            return false;
        } else {
            writeBarrier(blk, i, v_old, v_new);
            return true;
        }
    }
}

pub fn atomicLoad(blk: value.Value, i: usize) callconv(.C) value.Value {
    const fld = value.fieldPtr(blk, i);
    if (domain.alone()) {
        return @atomicLoad(value.Value, fld, .Monotonic);
    } else {
        @fence(.Acquire);
        return @atomicLoad(value.Value, fld, .SeqCst);
    }
}

pub fn atomicExchange(blk: value.Value, i: usize, v: value.Value) callconv(.C) value.Value {
    const fld = value.fieldPtr(blk, i);
    var res: value.Value = undefined;
    if (domain.alone()) {
        res = @atomicLoad(value.Value, fld, .Monotonic);
        @atomicStore(value.Value, fld, v, .Monotonic);
    } else {
        @fence(.Acquire);
        res = @atomicRmw(value.Value, fld, .Xchg, v, .SeqCst);
        @fence(.Release);
    }
    writeBarrier(blk, i, res, v);
    return res;
}

pub fn atomicFetchAdd(blk: value.Value, i: usize, incr: value.Value) callconv(.C) value.Value {
    const fld = value.fieldPtr(blk, i);
    var res: value.Value = undefined;
    if (domain.alone()) {
        res = @atomicLoad(value.Value, fld, .Monotonic);
        @atomicStore(value.Value, fld, value.ofInt(value.toInt(res) + value.toInt(incr)), .Monotonic);
    } else {
        res = @atomicRmw(value.Value, fld, .Add, value.toInt(incr) * 2, .SeqCst);
        @fence(.Release);
    }
    return res;
}

pub fn allocShared(wsz: usize, tag: value.Tag, rsv: value.Reserved) callconv(.C) value.Value {
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

// TODO
pub fn registerGenerationalGlobalRoot(root: *value.Value) callconv(.C) void {
    _ = root;
}
// TODO
pub fn modifyGenerationalGlobalRoot(root: *value.Value, val: value.Value) callconv(.C) void {
    _ = root;
    _ = val;
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
            return @ptrCast(@as([*]Self, @ptrCast(@alignCast(data))) - 1);
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

    pub fn create() void {
        if (Block.pool == null) {
            const blk = @as(*Block, @ptrCast(@alignCast(std.c.malloc(@sizeOf(Block)) orelse misc.fatalError("Fatal error: out of memory.\n"))));
            Block.pool = blk;
            Block.pool.?.next = blk;
            Block.pool.?.prev = blk;
        }
    }

    pub fn destroy() void {
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
            const blk = @as(*Block, @ptrCast(@alignCast(std.c.malloc(@sizeOf(Block) + sz * @sizeOf(T)) orelse return null)));
            blk.link();
            return blk.dataAs(T);
        } else {
            return @ptrCast(@alignCast(std.c.malloc(sz * @sizeOf(T))));
        }
    }
    pub fn alloc1Noexc(comptime T: type) ?*T {
        return allocNoexc(T, 1);
    }
    pub fn alloc(comptime T: type, sz: usize) ?[*]T {
        const res = allocNoexc(T, sz);
        if (res == null and sz != 0) {
            fail.raiseOutOfMemory();
        }
        return res;
    }
    pub fn alloc1(comptime T: type) ?*T {
        return alloc(T, 1);
    }

    pub fn free(data: anytype) void {
        if (Block.pool) |_| {
            const blk = Block.get(data);
            blk.unlink();
            std.c.free(blk);
        } else {
            std.c.free(@ptrCast(data));
        }
    }

    pub fn resizeNoexc(comptime T: type, data: ?[*]T, sz: usize) ?[*]T {
        const data_ = data orelse return allocNoexc(T, sz);
        if (Block.pool) |_| {
            const blk = Block.get(data_);
            blk.unlink();
            const new_blk = @as(*Block, @ptrCast(@alignCast(std.c.realloc(blk, @sizeOf(Block) + sz * @sizeOf(T)) orelse {
                blk.link();
                return null;
            })));
            new_blk.link();
            return new_blk.dataAs(T);
        } else {
            return @ptrCast(@alignCast(std.c.realloc(@ptrCast(data), sz)));
        }
    }
    pub fn resize(comptime T: type, data: ?[*]T, sz: usize) [*]T {
        return resizeNoexc(T, data, sz) orelse fail.raiseOutOfMemory();
    }

    pub fn stringDupNoexc(str: []const u8) ?[]const u8 {
        const res = allocNoexc(u8, str.len) orelse return null;
        @memcpy(res, str);
        return res[0..str.len];
    }
    pub fn stringDup(str: []const u8) []const u8 {
        return stringDupNoexc(str) orelse fail.raiseOutOfMemory();
    }

    const Allocator = struct {
        fn header(ptr: [*]u8) *[*]u8 {
            return @as(*[*]u8, @ptrFromInt(@intFromPtr(ptr) - @sizeOf(usize)));
        }
        fn alloc_(_: *anyopaque, sz: usize, log2_alignment: u8, _: usize) ?[*]u8 {
            const alignment = @as(usize, 1) << @as(std.math.Log2Int(usize), @intCast(log2_alignment));
            const unaligned_ptr = alloc(u8, sz + alignment - 1 + @sizeOf(usize)) orelse return null;
            const aligned_ptr = @as([*]u8, @ptrFromInt(std.mem.alignForward(usize, @intFromPtr(unaligned_ptr) + @sizeOf(usize), alignment)));
            header(aligned_ptr).* = unaligned_ptr;
            return aligned_ptr;
        }
        fn resize_(_: *anyopaque, buf: []u8, _: u8, sz: usize, _: usize) bool {
            return sz <= buf.len;
        }
        fn free_(_: *anyopaque, buf: []u8, _: u8, _: usize) void {
            free(header(buf.ptr).*);
        }
    };
    const allocator_vtable = std.mem.Allocator.VTable{
        .alloc = Allocator.alloc_,
        .resize = Allocator.resize_,
        .free = Allocator.free_,
    };
    pub const allocator = std.mem.Allocator{
        .ptr = undefined,
        .vtable = &allocator_vtable,
    };
};
