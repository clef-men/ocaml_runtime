const value = @import("value.zig");

// TODO
pub extern fn fatalUncaughtException(exn: value.Value) noreturn;
