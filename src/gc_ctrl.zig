comptime {
    @export(max_stack_wsize, .{ .name = "caml_max_stack_wsize" });
}

pub var max_stack_wsize: usize =
    undefined;
