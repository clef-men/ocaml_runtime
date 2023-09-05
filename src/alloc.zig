const std = @import("std");

const config = @import("config.zig");
const value = @import("value.zig");
const memory = @import("memory.zig");
const domain = @import("domain.zig");
const minor_gc = @import("minor_gc.zig");

pub fn alloc(wsz: usize, tag: value.Tag) value.Value {
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

pub export fn allocSharedCheckGc(wsz: usize, tag: value.Tag) value.Value {
    minor_gc.checkUrgentGc(value.unit);
    return memory.allocShared(wsz, tag, 0);
}

fn allocSmallAuxGc(state: *domain.State, wsz: usize, vals: [*]value.Value) void {
    const frame = memory.Frame.create();
    defer frame.destroy();

    const roots = memory.Roots.make(@ptrCast(vals + wsz), wsz);
    frame.add(&roots);

    for (0..wsz) |i| {
        vals[wsz + i] = vals[i];
    }
    memory.allocSmallGc(state, wsz, {});
    for (0..wsz) |i| {
        vals[i] = vals[wsz + i];
    }
}
fn allocSmallAux(comptime wsz: comptime_int, tag: value.Tag, vals: *[2 * wsz]value.Value) value.Value {
    domain.checkState();
    std.debug.assert(tag <= value.tag_max);
    const blk = memory.allocSmall(wsz, tag, [*]value.Value, allocSmallAuxGc, vals);
    for (0..wsz) |i| {
        value.setField(blk, i, vals[i]);
    }
    return blk;
}
pub export fn allocSmall0(tag: value.Tag) value.Value {
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
pub export fn allocSmall1(tag: value.Tag, val1: value.Value) value.Value {
    var vals = [_]value.Value{val1} ++ [1]value.Value{value.unit} ** 1;
    return allocSmallAux(1, tag, &vals);
}
pub export fn allocSmall2(tag: value.Tag, val1: value.Value, val2: value.Value) value.Value {
    var vals = [_]value.Value{ val1, val2 } ++ [1]value.Value{value.unit} ** 2;
    return allocSmallAux(2, tag, &vals);
}
pub export fn allocSmall3(tag: value.Tag, val1: value.Value, val2: value.Value, val3: value.Value) value.Value {
    var vals = [_]value.Value{ val1, val2, val3 } ++ [1]value.Value{value.unit} ** 3;
    return allocSmallAux(3, tag, &vals);
}
pub export fn allocSmall4(tag: value.Tag, val1: value.Value, val2: value.Value, val3: value.Value, val4: value.Value) value.Value {
    var vals = [_]value.Value{ val1, val2, val3, val4 } ++ [1]value.Value{value.unit} ** 4;
    return allocSmallAux(4, tag, &vals);
}
pub export fn allocSmall5(tag: value.Tag, val1: value.Value, val2: value.Value, val3: value.Value, val4: value.Value, val5: value.Value) value.Value {
    var vals = [_]value.Value{ val1, val2, val3, val4, val5 } ++ [1]value.Value{value.unit} ** 5;
    return allocSmallAux(5, tag, &vals);
}
pub export fn allocSmall6(tag: value.Tag, val1: value.Value, val2: value.Value, val3: value.Value, val4: value.Value, val5: value.Value, val6: value.Value) value.Value {
    var vals = [_]value.Value{ val1, val2, val3, val4, val5, val6 } ++ [1]value.Value{value.unit} ** 6;
    return allocSmallAux(6, tag, &vals);
}
pub export fn allocSmall7(tag: value.Tag, val1: value.Value, val2: value.Value, val3: value.Value, val4: value.Value, val5: value.Value, val6: value.Value, val7: value.Value) value.Value {
    var vals = [_]value.Value{ val1, val2, val3, val4, val5, val6, val7 } ++ [1]value.Value{value.unit} ** 7;
    return allocSmallAux(7, tag, &vals);
}
pub export fn allocSmall8(tag: value.Tag, val1: value.Value, val2: value.Value, val3: value.Value, val4: value.Value, val5: value.Value, val6: value.Value, val7: value.Value, val8: value.Value) value.Value {
    var vals = [_]value.Value{ val1, val2, val3, val4, val5, val6, val7, val8 } ++ [1]value.Value{value.unit} ** 8;
    return allocSmallAux(8, tag, &vals);
}
pub export fn allocSmall9(tag: value.Tag, val1: value.Value, val2: value.Value, val3: value.Value, val4: value.Value, val5: value.Value, val6: value.Value, val7: value.Value, val8: value.Value, val9: value.Value) value.Value {
    var vals = [_]value.Value{ val1, val2, val3, val4, val5, val6, val7, val8, val9 } ++ [1]value.Value{value.unit} ** 9;
    return allocSmallAux(9, tag, &vals);
}
pub export fn allocSmall(wsz: usize, tag: value.Tag) value.Value {
    std.debug.assert(0 < wsz);
    std.debug.assert(wsz <= config.max_young_wsize);
    std.debug.assert(tag <= value.tag_max);
    std.debug.assert(tag != value.tag_infix);
    return memory.allocSmall(wsz, tag, void, memory.allocSmallGc, {});
}

pub export fn allocString(sz: usize) value.Value {
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
