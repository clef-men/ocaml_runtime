const std = @import("std");

const value = @import("value.zig");
const memory = @import("memory.zig");
const alloc = @import("alloc.zig");
const domain = @import("domain.zig");
const signal = @import("signal.zig");
const io = @import("io.zig");
const printexc = @import("printexc.zig");

const exception = struct {
    pub extern const out_of_memory: value.Value;
    pub extern const sys_error: value.Value;
    pub extern const failure: value.Value;
    pub extern const invalid_argument: value.Value;
    pub extern const end_of_file: value.Value;
    pub extern const division_by_zero: value.Value;
    pub extern const not_found: value.Value;
    pub extern const match_failure: value.Value;
    pub extern const sys_blocked_io: value.Value;
    pub extern const stack_overflow: value.Value;
    pub extern const assert_failure: value.Value;
    pub extern const undefined_recursive_module: value.Value;
};

pub extern fn raiseException(state: *domain.State, val: value.Value) noreturn;

pub export fn raise(v: value.Value) noreturn {
    domain.checkState();

    io.unlockException();

    std.debug.assert(!value.isException(v));

    var v_ = signal.processPendingActionsWithRootExn(v);
    if (value.isException(v_)) {
        v_ = value.exception(v_);
    }

    if (domain.state.?.c_stack) |c_stack| {
        while (domain.state.?.local_roots) |local_roots| {
            if (@intFromPtr(c_stack) <= @intFromPtr(local_roots)) {
                break;
            }
            domain.state.?.local_roots = local_roots.next;
        }
        raiseException(domain.state.?, v_);
    } else {
        signal.terminateSignals();
        printexc.fatalUncaughtException(v_);
    }
}
pub export fn raiseWithArgument(tag: value.Value, arg: value.Value) noreturn {
    const frame = memory.Frame.create();
    defer frame.destroy();

    var bucket = value.unit;
    const roots = memory.Roots.make3(&tag, &arg, &bucket);
    frame.add(&roots);

    bucket = alloc.allocSmall(2, 0);
    value.setField(bucket, 0, tag);
    value.setField(bucket, 1, arg);
    raise(bucket);
}
pub fn raiseWithString(tag: value.Value, msg: []const u8) noreturn {
    const frame = memory.Frame.create();
    defer frame.destroy();

    const roots = memory.Roots.make1(&tag);
    frame.add(&roots);

    raiseWithArgument(tag, alloc.copyString(msg));
}
pub export fn raiseIfException(v: value.Value) void {
    if (value.isException(v)) {
        raise(value.exception(v));
    }
}

pub fn invalidArgument(msg: []const u8) noreturn {
    raiseWithString(exception.invalid_argument, msg);
}

pub export fn raiseOutOfMemory() noreturn {
    raise(exception.out_of_memory);
}
