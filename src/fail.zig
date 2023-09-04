const value = @import("value.zig");

// TODO
pub extern fn raise(val: value.Value) noreturn;
// TODO
pub fn invalidArgument(msg: []const u8) noreturn {
    _ = msg;
    unreachable;
}
// TODO
pub extern fn raiseOutOfMemory() noreturn;

// TODO
pub extern fn raiseIfException(val: value.Value) void;
