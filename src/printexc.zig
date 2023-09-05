const value = @import("value.zig");

// TODO
pub fn fatalUncaughtException(exn: value.Value) noreturn {
    _ = exn;
    unreachable;
}
