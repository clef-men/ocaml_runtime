const builtin = @import("builtin");

comptime {
    @export(stack_init_wsize, .{ .name = "caml_stack_init_wsize" });
    @export(max_young_wsize, .{ .name = "caml_max_young_wsize" });
    @export(min_major_slice_work, .{ .name = "caml_min_major_slice_work" });
}

pub const stack_init_wsize: usize =
    if (builtin.mode == .Debug) 64 else 4096;
pub const stack_threshold_wsize: usize =
    32;

pub const max_young_wsize: usize =
    256;
pub const min_major_slice_work: usize =
    512;
