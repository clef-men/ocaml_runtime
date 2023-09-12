const value = @import("value.zig");
const domain = @import("domain.zig");

comptime {
    @export(auto_triggered_major_slice, .{ .name = "caml_auto_triggered_major_slice" });
}

pub const auto_triggered_major_slice: isize =
    -1;

// TODO
pub fn darken(state: *domain.State, v: value.Value, ignored: ?*value.Value) void {
    _ = state;
    _ = v;
    _ = ignored;
}

pub fn opportunisticMajorWorkAvailable() bool {
    const state = domain.state.?;
    return !state.sweeping_done or !state.marking_done;
}

// TODO
pub fn opportunisticMajorCollectionSlice(howmuch: isize) void {
    _ = howmuch;
}
// TODO
pub fn majorCollectionSlice(howmuch: isize) void {
    _ = howmuch;
}
