const std = @import("std");

const value = @import("value.zig");
const memory = @import("memory.zig");
const domain = @import("domain.zig");
const fail = @import("fail.zig");
const final = @import("final.zig");

comptime {
    @export(setActionPending, .{ .name = "caml_signal_set_action_pending" });
    @export(checkPendingActions, .{ .name = "caml_signal_check_pending_actions" });
    @export(doPendingActionsExn, .{ .name = "caml_signal_do_pending_actions_exn" });
    @export(processPendingActionsWithRootExn, .{ .name = "caml_signal_process_pending_actions_with_root_exn" });
    @export(processPendingActionsWithRoot, .{ .name = "caml_signal_process_pending_actions_with_root" });
    @export(processPendingActionsExn, .{ .name = "caml_signal_process_pending_actions_exn" });
    @export(processPendingActions, .{ .name = "caml_signal_process_pending_actions" });
}

// TODO
pub fn processPendingSignalsExn() value.Value {
    return undefined;
}

// TODO
pub fn requestMajorSlice(global: bool) void {
    _ = global;
}
// TODO
pub fn requestMinorGc() void {}

pub fn setActionPending(state: *domain.State) callconv(.C) void {
    state.action_pending = true;
    state.young_limit.store(std.math.maxInt(usize), .Release);
}
pub fn checkPendingActions() callconv(.C) bool {
    domain.checkState();
    const state = domain.state.?;
    return domain.checkGcInterrupt(state) or state.action_pending;
}
pub fn doPendingActionsExn() callconv(.C) value.Value {
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
pub fn processPendingActionsWithRootExn(root: value.Value) callconv(.C) value.Value {
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
pub fn processPendingActionsWithRoot(root: value.Value) callconv(.C) value.Value {
    const exn = processPendingActionsWithRootExn(root);
    fail.raiseIfException(exn);
    return exn;
}
pub fn processPendingActionsExn() callconv(.C) value.Value {
    return processPendingActionsWithRootExn(value.unit);
}
pub fn processPendingActions() callconv(.C) void {
    _ = processPendingActionsWithRoot(value.unit);
}

// TODO
pub fn terminateSignals() void {}
