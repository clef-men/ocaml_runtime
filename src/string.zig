const std = @import("std");

const value = @import("value.zig");
const alloc = @import("alloc.zig");
const fail = @import("fail.zig");

comptime {
    @export(size, .{ .name = "caml_string_length" });
    @export(create, .{ .name = "caml_string_create" });
    @export(get, .{ .name = "caml_string_get" });
    @export(set, .{ .name = "caml_string_set" });
    @export(equal, .{ .name = "caml_string_equal" });
    @export(notequal, .{ .name = "caml_string_notequal" });
    @export(compare, .{ .name = "caml_string_compare" });
    @export(lessthan, .{ .name = "caml_string_lessthan" });
    @export(lessequal, .{ .name = "caml_string_lessequal" });
    @export(greaterthan, .{ .name = "caml_string_greaterthan" });
    @export(greaterequal, .{ .name = "caml_string_greaterequal" });
    @export(blit, .{ .name = "caml_string_blit" });
    @export(fill, .{ .name = "caml_string_fill" });
}

pub fn size(str: value.Value) callconv(.C) value.Value {
    return value.ofUint(value.stringSize(str));
}

pub fn create(sz: value.Value) callconv(.C) value.Value {
    const sz_ = value.toUint(sz);
    if (value.size_max * @sizeOf(usize) <= sz_) {
        fail.invalidArgument("String.create");
    }
    return alloc.allocString(sz_);
}

pub fn get(str: value.Value, i: value.Value) callconv(.C) value.Value {
    const i_ = value.toInt(i);
    if (i_ < 0 or value.stringSize(str) <= i_) {
        fail.boundError();
    }
    return value.ofInt(value.byte(str, @intCast(i)));
}

pub fn set(str: value.Value, i: value.Value, val: value.Value) callconv(.C) value.Value {
    const i_ = value.ofInt(i);
    if (i_ < 0 or value.stringSize(str) <= i_) {
        fail.boundError();
    }
    value.setByte(str, @intCast(i_), value.toU8(val));
    return value.unit;
}

pub fn equal(str1: value.Value, str2: value.Value) callconv(.C) value.Value {
    if (str1 == str2) {
        return value.true_;
    }
    var sz1 = value.size(str1);
    const sz2 = value.size(str2);
    if (sz1 != sz2) {
        return value.false_;
    }
    var flds1 = value.fields(str1);
    var flds2 = value.fields(str2);
    while (0 < sz1) : ({
        sz1 -= 1;
        flds1 += 1;
        flds2 += 1;
    }) {
        if (flds1[0] != flds2[0]) {
            return value.false_;
        }
    }
    return value.true_;
}
pub fn notequal(str1: value.Value, str2: value.Value) callconv(.C) value.Value {
    return value.not(equal(str1, str2));
}

pub fn compare(str1: value.Value, str2: value.Value) callconv(.C) value.Value {
    if (str1 == str2) {
        return value.ofInt(0);
    }
    return switch (std.mem.orderZ(u8, value.cstring(str1), value.cstring(str2))) {
        .gt => value.ofInt(1),
        .lt => value.ofInt(-1),
        .eq => value.ofInt(0),
    };
}

pub fn lessthan(str1: value.Value, str2: value.Value) callconv(.C) value.Value {
    return if (compare(str1, str2) < value.ofInt(0)) value.true_ else value.false_;
}
pub fn lessequal(str1: value.Value, str2: value.Value) callconv(.C) value.Value {
    return if (compare(str1, str2) <= value.ofInt(0)) value.true_ else value.false_;
}
pub fn greaterthan(str1: value.Value, str2: value.Value) callconv(.C) value.Value {
    return if (0 < compare(str1, str2)) value.true_ else value.false_;
}
pub fn greaterequal(str1: value.Value, str2: value.Value) callconv(.C) value.Value {
    return if (0 <= compare(str1, str2)) value.true_ else value.false_;
}

pub fn blit(str1: value.Value, i1_: value.Value, str2: value.Value, i2_: value.Value, n: value.Value) callconv(.C) value.Value {
    // FIXME: where is memmove?
    @memcpy((value.bytes(str2) + value.toUint(i2_))[0..value.toUint(n)], value.bytes(str1) + value.toUint(i1_));
    return value.unit;
}

pub fn fill(str: value.Value, i: value.Value, n: value.Value, init: value.Value) callconv(.C) value.Value {
    @memset((value.bytes(str) + value.toUint(i))[0..value.toUint(n)], value.toU8(init));
    return value.unit;
}
