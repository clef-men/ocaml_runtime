const value = @import("value.zig");
const domain = @import("domain.zig");

comptime {
    @export(auto_triggered_major_slice, .{ .name = "caml_auto_triggered_major_slice" });
}

// TODO
pub fn darken(state: *domain.State, v: value.Value, ignored: ?*value.Value) void {
    _ = state;
    _ = v;
    _ = ignored;
}

pub const auto_triggered_major_slice: isize =
    -1;

// TODO
pub fn majorCollectionSlice(howmuch: isize) void {
    _ = howmuch;
}
