const value = @import("value.zig");
const domain = @import("domain.zig");

// TODO
pub extern fn darken(state: *domain.State, val: value.Value, ignored: ?*value.Value) void;

pub export const auto_triggered_major_slice: isize =
    -1;

// TODO
pub extern fn majorCollectionSlice(howmuch: isize) void;
