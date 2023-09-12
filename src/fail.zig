const std = @import("std");

const value = @import("value.zig");
const memory = @import("memory.zig");
const alloc = @import("alloc.zig");
const domain = @import("domain.zig");
const signal = @import("signal.zig");
const callback = @import("callback.zig");
const io = @import("io.zig");
const printexc = @import("printexc.zig");

comptime {
    @export(raise, .{ .name = "caml_raise_" });
    @export(raiseWithArgument, .{ .name = "caml_raise_with_argument" });
    @export(raiseIfException, .{ .name = "caml_raise_if_exception" });
    @export(raiseOutOfMemory, .{ .name = "caml_raise_out_of_memory" });
    @export(boundError, .{ .name = "caml_bound_error" });
}

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

pub fn raise(v: value.Value) callconv(.C) noreturn {
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
pub fn raiseWithArgument(tag: value.Value, arg: value.Value) callconv(.C) noreturn {
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
pub fn raiseIfException(v: value.Value) callconv(.C) void {
    if (value.isException(v)) {
        raise(value.exception(v));
    }
}

pub fn invalidArgument(msg: []const u8) noreturn {
    raiseWithString(exception.invalid_argument, msg);
}

pub fn raiseOutOfMemory() callconv(.C) noreturn {
    raise(exception.out_of_memory);
}

fn boundExn() value.Value {
    const static = struct {
        var exn =
            std.atomic.Atomic(?*const value.Value).init(null);
    };
    if (static.exn.load(.Acquire)) |exn| {
        return exn.*;
    } else {
        if (callback.named_value.get("Pervasives.bound_error")) |exn| {
            static.exn.store(exn, .Release);
            return exn.*;
        } else {
            std.io.getStdErr().writeAll("Fatal error: exception Invalid_argument(\"index out of bounds\")\n") catch unreachable;
            std.os.exit(2);
        }
    }
}
pub fn boundError() callconv(.C) noreturn {
    raise(boundExn());
}
