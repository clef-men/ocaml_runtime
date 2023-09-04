const value = @import("value.zig");

// TODO
pub const State =
    void;

// TODO
pub fn tryAllocShared(state: *State, wsz: usize, tag: value.Tag, rsv: value.Reserved, pinned: bool) ?value.Value {
    _ = state;
    _ = wsz;
    _ = tag;
    _ = rsv;
    _ = pinned;
    return undefined;
}
