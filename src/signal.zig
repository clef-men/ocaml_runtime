const std = @import("std");

const value = @import("value.zig");
const memory = @import("memory.zig");
const domain = @import("domain.zig");
const fail = @import("fail.zig");
const final = @import("final.zig");

// TODO
pub extern fn processPendingSignalsExn() value.Value;

// TODO
pub extern fn requestMajorSlice(global: bool) void;
// TODO
pub extern fn requestMinorGc() void;

pub export fn setActionPending(state: *domain.State) void {
    state.action_pending = true;
    state.young_limit.store(std.math.maxInt(usize), .Release);
}
pub export fn checkPendingActions() bool {
    domain.checkState();
    const state = domain.state.?;
    return domain.checkGcInterrupt(state) or state.action_pending;
}
pub export fn doPendingActionsExn() value.Value {
    domain.state.?.action_pending = false;
    domain.handleGcInterrupt();

    var exn = processPendingSignalsExn();
    return blk: {
        if (value.isException(exn))
            break :blk error.Exception;

        exn = final.doCallsExn();
        if (value.isException(exn))
            break :blk error.Exception;

        break :blk value.unit;
    } catch blk: {
        setActionPending(domain.state.?);
        break :blk exn;
    };
}
pub export fn processPendingActionsWithRootExn(root: value.Value) value.Value {
    if (checkPendingActions()) {
        const frame = memory.Frame.create();
        defer frame.destroy();

        const roots = memory.Roots.make1(&root);
        frame.add(&roots);

        const exn = doPendingActionsExn();
        if (value.isException(exn)) {
            return exn;
        }
    }
    return root;
}
pub export fn processPendingActionsWithRoot(root: value.Value) value.Value {
    const exn = processPendingActionsWithRootExn(root);
    fail.raiseIfException(exn);
    return exn;
}
pub export fn processPendingActionsExn() value.Value {
    return processPendingActionsWithRootExn(value.unit);
}
pub export fn processPendingActions() void {
    _ = processPendingActionsWithRoot(value.unit);
}

// TODO
pub extern fn terminateSignals() void;
