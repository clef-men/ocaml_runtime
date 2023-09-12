const std = @import("std");

const value = @import("value.zig");
const memory = @import("memory.zig");
const fail = @import("fail.zig");

comptime {
    @export(named_value.register, .{ .name = "caml_named_value_register" });
}

pub const named_value = struct {
    var map =
        std.StringHashMap(value.Value).init(memory.static.allocator);
    var mutex =
        std.Thread.Mutex{};

    pub fn register(name: value.Value, val: value.Value) callconv(.C) void {
        const name_ = value.string(name);

        mutex.lock();
        defer mutex.unlock();

        const put_res = map.getOrPut(name_) catch fail.raiseOutOfMemory();
        if (put_res.found_existing) {
            memory.modifyGenerationalGlobalRoot(put_res.value_ptr, val);
        } else {
            put_res.key_ptr.ptr = memory.static.stringDup(name_).ptr;
            put_res.value_ptr.* = val;
            memory.registerGenerationalGlobalRoot(put_res.value_ptr);
        }
    }
    pub fn get(name: []const u8) ?*const value.Value {
        mutex.lock();
        defer mutex.unlock();

        return map.getPtr(name);
    }
};
