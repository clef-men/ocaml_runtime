const std = @import("std");

const config = @import("config.zig");
const value = @import("value.zig");
const memory = @import("memory.zig");
const alloc = @import("alloc.zig");
const minor_gc = @import("minor_gc.zig");
const fail = @import("fail.zig");
const signal = @import("signal.zig");
const event = @import("event.zig");

comptime {
    @export(size, .{ .name = "caml_array_length" });
    @export(get, .{ .name = "caml_array_get" });
    @export(set, .{ .name = "caml_array_set" });
    @export(unsafeGet, .{ .name = "caml_array_unsafe_get" });
    @export(unsafeSet, .{ .name = "caml_array_unsafe_set" });
}

pub fn size(arr: value.Value) callconv(.C) usize {
    return value.size(arr);
}

pub fn get(arr: value.Value, idx: value.Value) callconv(.C) value.Value {
    const idx_ = value.toInt(idx);
    if (idx_ < 0 or value.size(arr) <= idx_) {
        fail.boundError();
    }
    return value.field(arr, @intCast(idx_));
}

pub fn set(arr: value.Value, idx: value.Value, v: value.Value) callconv(.C) value.Value {
    const idx_ = value.toInt(idx);
    if (idx_ < 0 or value.size(arr) <= idx_) {
        fail.boundError();
    }
    memory.setField(arr, @intCast(idx_), v);
    return value.unit;
}

pub fn unsafeGet(arr: value.Value, idx: value.Value) callconv(.C) value.Value {
    return value.field(arr, value.toUint(idx));
}

pub fn unsafeSet(arr: value.Value, idx: value.Value, v: value.Value) callconv(.C) value.Value {
    memory.setField(arr, value.toUint(idx), v);
    return value.unit;
}

pub fn make(len: value.Value, init: value.Value) callconv(.C) value.Value {
    const frame = memory.Frame.create();
    defer frame.destroy();

    var res = value.unit;
    var roots = memory.Roots.make3(&len, &init, &res);
    frame.add(&roots);

    defer signal.processPendingActions();

    const len_ = value.toUint(len);
    if (len_ == 0) {
        return alloc.allocSmall0(0);
    } else if (len_ <= config.max_young_wsize) {
        var blk = alloc.allocSmall(len_, 0);
        for (0..len_) |i| {
            value.setField(blk, i, init);
        }
        return blk;
    } else if (value.size_max < len_) {
        fail.invalidArgument("Array.make");
    } else {
        if (value.isBlock(init) and value.isYoung(init)) {
            event.counter(.force_minor_array_make, 1);
            minor_gc.collect();
        }
        std.debug.assert(!value.isBlock(init) or !value.isYoung(init));
        var blk = memory.allocShared(len_, 0, 0);
        for (0..len_) |i| {
            value.setField(blk, i, init);
        }
        return blk;
    }
}
