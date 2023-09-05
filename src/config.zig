comptime {
    @export(max_young_wsize, .{ .name = "caml_max_young_wsize" });
}

pub const max_young_wsize: usize =
    256;
