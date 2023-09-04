const value = @import("value.zig");

// TODO
pub extern fn processPendingActions() void;

// TODO
pub extern fn requestMajorSlice(global: bool) void;
// TODO
pub extern fn requestMinorGc() void;

// TODO
pub extern fn doPendingActionsExn() value.Value;
