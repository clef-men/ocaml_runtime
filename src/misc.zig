const std = @import("std");

const value = @import("value.zig");
const domain = @import("domain.zig");

comptime {
    @export(debug.isDebugTag, .{ .name = "caml_is_debug_tag" });
    @export(debug.free_minor, .{ .name = "caml_debug_free_minor" });
    @export(debug.free_major, .{ .name = "caml_debug_free_major" });
    @export(debug.free_shrink, .{ .name = "caml_debug_free_shrink" });
    @export(debug.free_truncate, .{ .name = "caml_debug_truncate" });
    @export(debug.free_unused, .{ .name = "caml_debug_unused" });
    @export(debug.uninit_minor, .{ .name = "caml_debug_uninit_minor" });
    @export(debug.uninit_major, .{ .name = "caml_debug_uninit_major" });
    @export(debug.uninit_align, .{ .name = "caml_debug_unit_align" });
    @export(debug.filler_align, .{ .name = "caml_debug_filler_align" });
    @export(debug.pool_magic, .{ .name = "caml_debug_pool_magic" });
    @export(debug.uninit_stat, .{ .name = "caml_debug_uninit_stat" });
    @export(noallocBegin, .{ .name = "caml_noalloc_begin" });
    @export(noallocEnd, .{ .name = "caml_noalloc_end" });
    @export(allocPoint, .{ .name = "caml_alloc_point" });
}

pub const debug = struct {
    pub fn makeValue(x: u8) value.Value {
        return @bitCast(if (@bitSizeOf(usize) == 64)
            0xD700D7D7D700D6D7 | (@as(usize, @intCast(x)) << 16) | (@as(usize, @intCast(x)) << 48)
        else
            0xD700D6D7 | (@as(usize, @intCast(x)) << 16));
    }
    pub fn isDebugTag(tag: value.Tag) callconv(.C) bool {
        return @bitCast(if (@bitSizeOf(usize) == 64)
            tag & 0xff00ffffff00ffff == 0xD700D7D7D700D6D7
        else
            tag & 0xff00ffff == 0xD700D6D7);
    }

    pub const free_minor =
        makeValue(0x00);
    pub const free_major =
        makeValue(0x01);
    pub const free_shrink =
        makeValue(0x03);
    pub const free_truncate =
        makeValue(0x04);
    pub const free_unused =
        makeValue(0x05);
    pub const uninit_minor =
        makeValue(0x10);
    pub const uninit_major =
        makeValue(0x11);
    pub const uninit_align =
        makeValue(0x15);
    pub const filler_align =
        makeValue(0x85);
    pub const pool_magic =
        makeValue(0x99);

    pub const uninit_stat: u8 =
        0xD7;
};

threadlocal var noalloc_level: isize =
    0;
pub fn noallocBegin() callconv(.C) isize {
    const lvl = noalloc_level;
    noalloc_level = lvl + 1;
    return lvl;
}
pub fn noallocEnd(lvl: *isize) callconv(.C) void {
    const curr_lvl = noalloc_level - 1;
    noalloc_level = curr_lvl;
    std.debug.assert(lvl.* == curr_lvl);
}
pub fn allocPoint() callconv(.C) void {
    std.debug.assert(noalloc_level == 0);
}

pub var verbose_gc =
    std.atomic.Atomic(usize).init(0);
pub fn gcLog(msg: []const u8) void {
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
