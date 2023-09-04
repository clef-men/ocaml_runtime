const value = @import("value.zig");

// TODO
pub fn namedValue(name: []const u8) ?*const value.Value {
    _ = name;
    return undefined;
}
