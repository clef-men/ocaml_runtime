const std = @import("std");

const value = @import("value.zig");
const domain = @import("domain.zig");

pub const debug = struct {
    pub export fn makeValue(x: u8) value.Value {
        return @bitCast(if (@bitSizeOf(usize) == 64)
            0xD700D7D7D700D6D7 | (@as(usize, @intCast(x)) << 16) | (@as(usize, @intCast(x)) << 48)
        else
            0xD700D6D7 | (@as(usize, @intCast(x)) << 16));
    }
    pub export fn isDebugTag(tag: value.Tag) bool {
        return @bitCast(if (@bitSizeOf(usize) == 64)
            tag & 0xff00ffffff00ffff == 0xD700D7D7D700D6D7
        else
            tag & 0xff00ffff == 0xD700D6D7);
    }

    pub export const free_minor =
        makeValue(0x00);
    pub export const free_major =
        makeValue(0x01);
    pub export const free_shrink =
        makeValue(0x03);
    pub export const free_truncate =
        makeValue(0x04);
    pub export const free_unused =
        makeValue(0x05);
    pub export const uninit_minor =
        makeValue(0x10);
    pub export const uninit_major =
        makeValue(0x11);
    pub export const uninit_align =
        makeValue(0x15);
    pub export const filler_align =
        makeValue(0x85);
    pub export const pool_magic =
        makeValue(0x99);

    pub export const uninit_stat: u8 =
        0xD7;
};

threadlocal var noalloc_level: isize =
    0;
pub export fn noallocBegin() isize {
    const lvl = noalloc_level;
    noalloc_level = lvl + 1;
    return lvl;
}
pub export fn noallocEnd(lvl: *isize) void {
    const curr_lvl = noalloc_level - 1;
    noalloc_level = curr_lvl;
    std.debug.assert(lvl.* == curr_lvl);
}
pub export fn allocPoint() void {
    std.debug.assert(noalloc_level == 0);
}

pub const verbose_gc =
    std.atomic.Atomic(usize).init(0);
pub fn gcLog(comptime msg: []const u8) void {
    if (verbose_gc.load(.Unordered) & 0x800 != 0) {
        const id: isize = if (domain.state) |state| @intCast(state.id) else -1;
        std.io.getStdErr().writer().print("[{d:02}] {s}\n", .{ id, msg }) catch unreachable;
    }
}
pub fn gcMessage(lvl: usize, msg: []const u8) void {
    if (verbose_gc.load(.Unordered) & lvl != 0) {
        std.io.getStdErr().writeAll(msg) catch unreachable;
    }
}

const FatalErrorHook =
    *const fn ([]const u8) void;
pub var fatal_error_hook =
    std.atomic.Atomic(?FatalErrorHook).init(null);
pub fn fatalError(msg: []const u8) noreturn {
    if (fatal_error_hook.load(.SeqCst)) |hook| {
        hook(msg);
    } else {
        std.io.getStdErr().writer().print("Fatal error: {s}\n", .{msg}) catch unreachable;
    }
    std.os.abort();
}
