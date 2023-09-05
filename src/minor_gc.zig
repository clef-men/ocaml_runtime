const std = @import("std");

const value = @import("value.zig");
const memory = @import("memory.zig");
const domain = @import("domain.zig");
const fail = @import("fail.zig");
const signal = @import("signal.zig");
const event = @import("event.zig");
const misc = @import("misc.zig");

pub fn Table(comptime T: type) type {
    return struct {
        size: usize,
        reserved: usize,
        base: ?[*]T,
        end: ?[*]T,
        threshold: ?[*]T,
        ptr: ?[*]T,
        limit: ?[*]T,

        const Self = @This();

        pub fn alloc(self: *Self, sz: usize, rsv: usize) void {
            self.size = sz;
            self.reserved = rsv;
            if (memory.static.allocNoexc(T, sz + rsv)) |base| {
                memory.static.free(self.base);
                self.base = base;
                self.end = base + sz + rsv;
                self.threshold = base + sz;
                self.ptr = base;
                self.limit = base + sz;
            } else {
                misc.fatalError("not enough memory");
            }
        }

        pub fn realloc(self: *Self) void {
            const name = if (T == *value.Value) "value" else if (T == Ephemeron) "ephemeron" else "custom";
            const ev_cntr: event.Counter = if (T == *value.Value) .request_minor_realloc_value_table else if (T == Ephemeron) .request_minor_realloc_ephemeron_table else .request_minor_realloc_custom_table;

            std.debug.assert(if (self.base) |_| self.ptr.? == self.limit.? else true);
            std.debug.assert(if (self.base) |_| @intFromPtr(self.limit.?) <= @intFromPtr(self.end.?) else true);
            std.debug.assert(if (self.base) |_| @intFromPtr(self.threshold.?) <= @intFromPtr(self.limit.?) else true);

            if (self.base) |base| {
                if (self.limit.? == self.threshold.?) {
                    event.counter(ev_cntr, 1);
                    misc.gcMessage(0x08, name ++ "_table threshold crossed\n");
                    self.limit = self.end.?;
                    signal.requestMinorGc();
                } else {
                    const ptr_ofs = @intFromPtr(self.ptr.?) - @intFromPtr(base);
                    self.size *= 2;
                    const sz = self.size + self.reserved;
                    const msg = std.fmt.allocPrint(std.heap.c_allocator, "Growing " ++ name ++ "_table to {}k bytes\n", .{sz * @sizeOf(T) / 1024}) catch unreachable;
                    defer std.heap.c_allocator.free(msg);
                    misc.gcMessage(0x80, msg);
                    if (memory.static.resizeNoexc(T, base, sz)) |base_| {
                        self.base = base_;
                        self.end = base_ + self.size + self.reserved;
                        self.threshold = base_ + self.size;
                        self.ptr = base_ + ptr_ofs;
                        self.limit = self.end;
                    } else {
                        misc.fatalError(name ++ "_table overflow");
                    }
                }
            } else {
                self.alloc(domain.state.?.minor_heap_wsize / 8, 256);
            }
        }

        pub fn init(self: *Self) void {
            self.size = 0;
            self.reserved = 0;
            self.base = null;
            self.end = null;
            self.threshold = null;
            self.ptr = null;
            self.limit = null;
        }

        pub fn reset(self: *Self) void {
            memory.static.free(self.base);
            self.init();
        }

        pub fn clear(self: *Self) void {
            self.ptr = self.base;
            self.limit = self.threshold;
        }

        pub fn add(self: *Self, t: T) void {
            std.debug.assert(self.base != null);
            if (@intFromPtr(self.limit.?) <= @intFromPtr(self.ptr.?)) {
                std.debug.assert(self.limit.? == self.ptr.?);
                self.realloc();
            }
            const ptr = self.ptr.?;
            self.ptr = ptr + 1;
            ptr[0] = t;
            if (T == Ephemeron) {
                std.debug.assert(ptr.offset < value.size(ptr.ephemeron));
            }
        }
    };
}

pub const ValueTable =
    Table(*value.Value);

pub const Ephemeron = struct {
    ephemeron: value.Value,
    offset: usize,
};
pub const EphemeronTable =
    Table(Ephemeron);

pub const Custom = struct {
    block: value.Value,
    mem: usize,
    max: usize,
};
pub const CustomTable =
    Table(Custom);

pub const Tables = struct {
    value_table: ValueTable,
    ephemeron_table: EphemeronTable,
    custom_table: CustomTable,

    const Self = @This();

    pub fn alloc() ?*Self {
        const self = memory.static.alloc1Noexc(Self);
        if (self) |self_| {
            self_.init();
        }
        return self;
    }

    pub fn reset(self: *Self) void {
        self.value_table.reset();
        self.ephemeron_table.reset();
        self.custom_table.reset();
    }

    pub fn free(self: *Self) void {
        std.debug.assert(self.value_table.ptr == self.value_table.base);
        self.reset();
        memory.static.free(self);
    }
};

pub export var num_collection =
    std.atomic.Atomic(usize).init(0);
pub export var major_slice_epoch =
    std.atomic.Atomic(usize).init(0);

// TODO
pub extern fn emptyMinorHeapsOnce() void;

pub export fn allocSmallDispatch(state: *domain.State, wsz: usize, flags: memory.AllocSmallFlags) void {
    const wsz_ = wsz + value.header_wsize;

    state.young_ptr += wsz_;

    while (true) {
        if (flags & memory.alloc_small_flags.from_ocaml != 0) {
            fail.raiseIfException(signal.doPendingActionsExn());
        } else {
            domain.handleGcInterrupt();
            state.action_pending = true;
        }

        if (@intFromPtr(state.young_start) <= @intFromPtr(state.young_ptr - wsz_)) {
            break;
        }

        event.counter(.force_minor_alloc_small, 1);
        domain.pollGcWork();
    }

    state.young_ptr -= wsz_;
}

pub export fn checkUrgentGc(root: value.Value) void {
    if (domain.checkGcInterrupt(domain.state.?)) {
        const frame = memory.Frame.create();
        defer frame.destroy();

        const roots = memory.Roots.make1(&root);
        frame.add(&roots);

        domain.handleGcInterrupt();
    }
}

// TODO
pub extern fn collect() void;
