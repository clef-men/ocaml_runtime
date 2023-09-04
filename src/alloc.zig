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
            const res = memory.allocSmall(wsz, tag, void, memory.allocSmallGc, {});
            if (tag < value.tag_no_scan) {
                for (0..wsz) |i| {
                    value.fieldPtr(res, i).* = value.unit;
                }
            }
            return res;
        }
    } else {
        const res = memory.allocShared(wsz, tag, 0);
        if (tag < value.tag_no_scan) {
            for (0..wsz) |i| {
                value.fieldPtr(res, i).* = value.unit;
            }
        }
        minor_gc.checkUrgentGc(res);
        return res;
    }
}

pub export fn allocSharedCheckGc(wsz: usize, tag: value.Tag) value.Value {
    minor_gc.checkUrgentGc(value.unit);
    return memory.allocShared(wsz, tag, 0);
}

fn allocSmallAuxGc(state: *domain.State, wsz: usize, vals: [*]value.Value) void {
    const frame = memory.Frame.begin();
    defer frame.end();

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
        @atomicStore(value.Value, value.fieldPtr(blk, i), vals[i], .Unordered);
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
pub export fn allocSmall1(tag: value.Tag, v1: value.Value) value.Value {
    var vals = [2 * 1]value.Value{ v1, value.unit };
    return allocSmallAux(1, tag, &vals);
}
pub export fn allocSmall2(tag: value.Tag, v1: value.Value, v2: value.Value) value.Value {
    var vals = [2 * 2]value.Value{ v1, v2, value.unit, value.unit };
    return allocSmallAux(2, tag, &vals);
}
pub export fn allocSmall3(tag: value.Tag, v1: value.Value, v2: value.Value, v3: value.Value) value.Value {
    var vals = [2 * 3]value.Value{ v1, v2, v3, value.unit, value.unit, value.unit };
    return allocSmallAux(3, tag, &vals);
}
pub export fn allocSmall4(tag: value.Tag, v1: value.Value, v2: value.Value, v3: value.Value, v4: value.Value) value.Value {
    var vals = [2 * 4]value.Value{ v1, v2, v3, v4, value.unit, value.unit, value.unit, value.unit };
    return allocSmallAux(4, tag, &vals);
}
pub export fn allocSmall5(tag: value.Tag, v1: value.Value, v2: value.Value, v3: value.Value, v4: value.Value, v5: value.Value) value.Value {
    var vals = [2 * 5]value.Value{ v1, v2, v3, v4, v5, value.unit, value.unit, value.unit, value.unit, value.unit };
    return allocSmallAux(5, tag, &vals);
}
pub export fn allocSmall6(tag: value.Tag, v1: value.Value, v2: value.Value, v3: value.Value, v4: value.Value, v5: value.Value, v6: value.Value) value.Value {
    var vals = [2 * 6]value.Value{ v1, v2, v3, v4, v5, v6, value.unit, value.unit, value.unit, value.unit, value.unit, value.unit };
    return allocSmallAux(6, tag, &vals);
}
pub export fn allocSmall7(tag: value.Tag, v1: value.Value, v2: value.Value, v3: value.Value, v4: value.Value, v5: value.Value, v6: value.Value, v7: value.Value) value.Value {
    var vals = [2 * 7]value.Value{ v1, v2, v3, v4, v5, v6, v7, value.unit, value.unit, value.unit, value.unit, value.unit, value.unit, value.unit };
    return allocSmallAux(7, tag, &vals);
}
pub export fn allocSmall8(tag: value.Tag, v1: value.Value, v2: value.Value, v3: value.Value, v4: value.Value, v5: value.Value, v6: value.Value, v7: value.Value, v8: value.Value) value.Value {
    var vals = [2 * 8]value.Value{ v1, v2, v3, v4, v5, v6, v7, v8, value.unit, value.unit, value.unit, value.unit, value.unit, value.unit, value.unit, value.unit };
    return allocSmallAux(8, tag, &vals);
}
pub export fn allocSmall9(tag: value.Tag, v1: value.Value, v2: value.Value, v3: value.Value, v4: value.Value, v5: value.Value, v6: value.Value, v7: value.Value, v8: value.Value, v9: value.Value) value.Value {
    var vals = [2 * 9]value.Value{ v1, v2, v3, v4, v5, v6, v7, v8, v9, value.unit, value.unit, value.unit, value.unit, value.unit, value.unit, value.unit, value.unit, value.unit };
    return allocSmallAux(9, tag, &vals);
}
pub export fn allocSmall(wsz: usize, tag: value.Tag) value.Value {
    std.debug.assert(0 < wsz);
    std.debug.assert(wsz <= config.max_young_wsize);
    std.debug.assert(tag <= value.tag_max);
    std.debug.assert(tag != value.tag_infix);
    return memory.allocSmall(wsz, tag, void, memory.allocSmallGc, {});
}
