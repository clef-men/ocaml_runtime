const std = @import("std");

const config = @import("config.zig");
const value = @import("value.zig");
const memory = @import("memory.zig");
const domain = @import("domain.zig");
const minor_gc = @import("minor_gc.zig");

comptime {
    @export(alloc, .{ .name = "caml_alloc_alloc" });
    @export(allocSharedCheckGc, .{ .name = "caml_alloc_shared_check_gc" });
    @export(allocSmall0, .{ .name = "caml_alloc_small0" });
    @export(allocSmall1, .{ .name = "caml_alloc_small1" });
    @export(allocSmall2, .{ .name = "caml_alloc_small2" });
    @export(allocSmall3, .{ .name = "caml_alloc_small3" });
    @export(allocSmall4, .{ .name = "caml_alloc_small4" });
    @export(allocSmall5, .{ .name = "caml_alloc_small5" });
    @export(allocSmall6, .{ .name = "caml_alloc_small6" });
    @export(allocSmall7, .{ .name = "caml_alloc_small7" });
    @export(allocSmall8, .{ .name = "caml_alloc_small8" });
    @export(allocSmall9, .{ .name = "caml_alloc_small9" });
    @export(allocSmall, .{ .name = "caml_alloc_small" });
    @export(allocString, .{ .name = "caml_alloc_string" });
}

pub fn alloc(wsz: usize, tag: value.Tag) callconv(.C) value.Value {
    std.debug.assert(tag <= value.tag_max);
    std.debug.assert(tag != value.tag_infix);
    if (wsz <= config.max_young_wsize) {
        if (wsz == 0) {
            return allocSmall0(tag);
        } else {
            domain.checkState();
            const blk = memory.allocSmall(wsz, tag, void, memory.allocSmallGc, {});
            if (tag < value.tag_no_scan) {
                for (0..wsz) |i| {
                    value.setField(blk, i, value.unit);
                }
            }
            return blk;
        }
    } else {
        const blk = memory.allocShared(wsz, tag, 0);
        if (tag < value.tag_no_scan) {
            for (0..wsz) |i| {
                value.setField(blk, i, value.unit);
            }
        }
        minor_gc.checkUrgentGc(blk);
        return blk;
    }
}

pub fn allocSharedCheckGc(wsz: usize, tag: value.Tag) callconv(.C) value.Value {
    minor_gc.checkUrgentGc(value.unit);
    return memory.allocShared(wsz, tag, 0);
}

fn allocSmallAuxGc(state: *domain.State, wsz: usize, vs: [*]value.Value) void {
    const frame = memory.Frame.create();
    defer frame.destroy();

    const roots = memory.Roots.make(@ptrCast(vs + wsz), wsz);
    frame.add(&roots);

    for (0..wsz) |i| {
        vs[wsz + i] = vs[i];
    }
    memory.allocSmallGc(state, wsz, {});
    for (0..wsz) |i| {
        vs[i] = vs[wsz + i];
    }
}
fn allocSmallAux(comptime wsz: comptime_int, tag: value.Tag, vs: *[2 * wsz]value.Value) value.Value {
    domain.checkState();
    std.debug.assert(tag <= value.tag_max);
    const blk = memory.allocSmall(wsz, tag, [*]value.Value, allocSmallAuxGc, vs);
    for (0..wsz) |i| {
        value.setField(blk, i, vs[i]);
    }
    return blk;
}
pub fn allocSmall0(tag: value.Tag) callconv(.C) value.Value {
    const static = struct {
        var atoms = blk: {
            @setEvalBranchQuota(2000);
            var atoms_: [value.tag_max + 1]value.Header = undefined;
            for (&atoms_, 0..) |*atom_, i| {
                atom_.* = value.headerMake(0, i, value.color_not_markable);
            }
            break :blk atoms_;
        };
    };
    return value.ofHeaderPtr(&static.atoms[tag]);
}
pub fn allocSmall1(tag: value.Tag, v1: value.Value) callconv(.C) value.Value {
    var vs = [_]value.Value{v1} ++ [1]value.Value{value.unit} ** 1;
    return allocSmallAux(1, tag, &vs);
}
pub fn allocSmall2(tag: value.Tag, v1: value.Value, v2: value.Value) callconv(.C) value.Value {
    var vs = [_]value.Value{ v1, v2 } ++ [1]value.Value{value.unit} ** 2;
    return allocSmallAux(2, tag, &vs);
}
pub fn allocSmall3(tag: value.Tag, v1: value.Value, v2: value.Value, v3: value.Value) callconv(.C) value.Value {
    var vs = [_]value.Value{ v1, v2, v3 } ++ [1]value.Value{value.unit} ** 3;
    return allocSmallAux(3, tag, &vs);
}
pub fn allocSmall4(tag: value.Tag, v1: value.Value, v2: value.Value, v3: value.Value, v4: value.Value) callconv(.C) value.Value {
    var vs = [_]value.Value{ v1, v2, v3, v4 } ++ [1]value.Value{value.unit} ** 4;
    return allocSmallAux(4, tag, &vs);
}
pub fn allocSmall5(tag: value.Tag, v1: value.Value, v2: value.Value, v3: value.Value, v4: value.Value, v5: value.Value) callconv(.C) value.Value {
    var vs = [_]value.Value{ v1, v2, v3, v4, v5 } ++ [1]value.Value{value.unit} ** 5;
    return allocSmallAux(5, tag, &vs);
}
pub fn allocSmall6(tag: value.Tag, v1: value.Value, v2: value.Value, v3: value.Value, v4: value.Value, v5: value.Value, v6: value.Value) callconv(.C) value.Value {
    var vs = [_]value.Value{ v1, v2, v3, v4, v5, v6 } ++ [1]value.Value{value.unit} ** 6;
    return allocSmallAux(6, tag, &vs);
}
pub fn allocSmall7(tag: value.Tag, v1: value.Value, v2: value.Value, v3: value.Value, v4: value.Value, v5: value.Value, v6: value.Value, v7: value.Value) callconv(.C) value.Value {
    var vs = [_]value.Value{ v1, v2, v3, v4, v5, v6, v7 } ++ [1]value.Value{value.unit} ** 7;
    return allocSmallAux(7, tag, &vs);
}
pub fn allocSmall8(tag: value.Tag, v1: value.Value, v2: value.Value, v3: value.Value, v4: value.Value, v5: value.Value, v6: value.Value, v7: value.Value, v8: value.Value) callconv(.C) value.Value {
    var vs = [_]value.Value{ v1, v2, v3, v4, v5, v6, v7, v8 } ++ [1]value.Value{value.unit} ** 8;
    return allocSmallAux(8, tag, &vs);
}
pub fn allocSmall9(tag: value.Tag, v1: value.Value, v2: value.Value, v3: value.Value, v4: value.Value, v5: value.Value, v6: value.Value, v7: value.Value, v8: value.Value, v9: value.Value) callconv(.C) value.Value {
    var vs = [_]value.Value{ v1, v2, v3, v4, v5, v6, v7, v8, v9 } ++ [1]value.Value{value.unit} ** 9;
    return allocSmallAux(9, tag, &vs);
}
pub fn allocSmall(wsz: usize, tag: value.Tag) callconv(.C) value.Value {
    std.debug.assert(0 < wsz);
    std.debug.assert(wsz <= config.max_young_wsize);
    std.debug.assert(tag <= value.tag_max);
    std.debug.assert(tag != value.tag_infix);
    return memory.allocSmall(wsz, tag, void, memory.allocSmallGc, {});
}

pub fn allocString(sz: usize) callconv(.C) value.Value {
    const wsz = (sz + @sizeOf(value.Value)) / @sizeOf(value.Value);
    const blk = blk: {
        if (wsz <= config.max_young_wsize) {
            domain.checkState();
            break :blk memory.allocSmall(wsz, value.tag_string, void, memory.allocSmallGc, {});
        } else {
            const blk = memory.allocShared(wsz, value.tag_string, 0);
            minor_gc.checkUrgentGc(blk);
            break :blk blk;
        }
    };
    value.setField(blk, wsz - 1, 0);
    const i = wsz * @sizeOf(usize) - 1;
    value.bytePtr(blk, i).* = @intCast(i - sz);
    return blk;
}
pub fn copyString(str: []const u8) value.Value {
    const blk = allocString(str.len);
    @memcpy(value.bytes(blk), str);
    return blk;
}
