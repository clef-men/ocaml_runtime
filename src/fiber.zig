const std = @import("std");

const config = @import("config.zig");
const value = @import("value.zig");
const memory = @import("memory.zig");
const domain = @import("domain.zig");
const gc_ctrl = @import("gc_ctrl.zig");
const misc = @import("misc.zig");

comptime {
    @export(Stack.base, .{ .name = "caml_stack_base" });
    @export(Stack.thresholdPtr, .{ .name = "caml_stack_threshold_ptr" });
    @export(Stack.high, .{ .name = "caml_stack_high" });
    @export(Stack.getInitWsize, .{ .name = "caml_stack_get_init_wsize" });
    @export(Stack.changeMaxWsize, .{ .name = "caml_stack_change_max_wsize" });
    @export(Stack.allocCache, .{ .name = "caml_alloc_cache" });
}

pub const Stack = struct {
    const Self = @This();

    const num_size_class: usize =
        5;

    stack_ptr: *anyopaque,
    exception_ptr: *anyopaque,
    handler: *Handler,
    cache_bucket: isize,
    size: usize,
    magic: usize,
    id: usize,

    const Handler = struct {
        handle_value: value.Value,
        handle_exception: value.Value,
        handle_effect: value.Value,
        parent: ?*Self,
    };

    pub fn base(self: *Self) callconv(.C) [*]value.Value {
        return @ptrCast(@as([*]Self, @ptrCast(self)) + 1);
    }
    pub fn thresholdPtr(self: *Self) callconv(.C) [*]value.Value {
        return self.base() + config.stack_threshold_wsize;
    }
    pub fn high(self: *Self) callconv(.C) [*]value.Value {
        return @ptrCast(self.handler);
    }

    pub fn getInitWsize() callconv(.C) usize {
        return @min(config.stack_init_wsize, gc_ctrl.max_stack_wsize);
    }

    pub fn changeMaxWsize(wsz: usize) callconv(.C) void {
        const current = domain.state.?.current_stack;
        const wsz_ = @max(wsz, @intFromPtr(current.high()) - @intFromPtr(current.stack_ptr) + config.stack_threshold_wsize);
        if (wsz_ != gc_ctrl.max_stack_wsize) {
            const msg = std.fmt.allocPrint(std.heap.c_allocator, "Changing stack limit to {}k bytes", .{wsz_ * @sizeOf(usize) / 1024}) catch unreachable;
            defer std.heap.c_allocator.free(msg);
            misc.gcLog(msg);
        }
        gc_ctrl.max_stack_wsize = wsz_;
    }

    pub fn allocCache() callconv(.C) ?[*]?*Self {
        const cache = memory.static.allocNoexc(?*Self, num_size_class) orelse return null;
        for (0..num_size_class) |i| {
            cache[i] = null;
        }
        return cache;
    }

    fn alloc(wsz: usize) ?*Self {
        const sz = @sizeOf(Self) + wsz * @sizeOf(value.Value) + 8 + @sizeOf(Handler);
        const stack = @as(*Self, @ptrCast(std.os.mmap(null, sz, std.os.PROT_READ | std.os.PROT_WRITE, std.os.MAP_ANONYMOUS | std.os.MAP_PRIVATE | std.os.MAP_STACK, -1, 0) catch return null));
        stack.size = sz;
        return stack;
    }
};

pub const CStack = struct {
    stack: *Stack,
    stack_ptr: *anyopaque,
    prev: *CStack,
};

var id =
    std.atomic.Atomic(usize).init(0);
