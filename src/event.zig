pub const Phase = enum {
    explicit_gc_set,
    explicit_gc_stat,
    explicit_gc_minor,
    explicit_gc_major,
    explicit_gc_full_major,
    explicit_gc_compact,
    major,
    major_sweep,
    major_mark_roots,
    major_mark,
    minor,
    minor_local_roots,
    minor_finalized,
    explicit_gc_major_slice,
    finalise_update_first,
    finalise_update_last,
    interrupt_remote,
    major_ephe_mark,
    major_ephe_sweep,
    major_finish_marking,
    major_gc_cycle_domains,
    major_gc_phase_change,
    major_gc_stw,
    major_mark_opportunistic,
    major_slice,
    major_finish_cycle,
    minor_clear,
    minor_finalizers_oldify,
    minor_global_roots,
    minor_leave_barrier,
    stw_api_barrier,
    stw_handler,
    stw_leader,
    major_finish_sweeping,
    minor_finalizers_admin,
    minor_remembered_set,
    minor_remembered_set_promote,
    minor_local_roots_promote,
    domain_condition_wait,
    domain_resize_heap_reservation,
};

pub const Counter = enum {
    force_minor_alloc_small,
    force_minor_array_make,
    force_minor_set_minor_heap_size,
    force_minor_memprof,
    minor_promoted,
    minor_allocated,
    request_major_alloc_shared,
    request_major_adjust_gc_speed,
    request_minor_realloc_value_table,
    request_minor_realloc_ephemeron_table,
    request_minor_realloc_custom_table,
    major_heap_pool_words,
    major_heap_pool_live_words,
    major_heap_large_words,
    major_heap_pool_frag_words,
    major_heap_pool_live_blocks,
    major_heap_large_blocks,
};

// TODO
pub fn begin(phase: Phase) void {
    _ = phase;
}
// TODO
pub fn end(phase: Phase) void {
    _ = phase;
}

// TODO
pub fn counter(cntr: Counter, _: usize) void {
    _ = cntr;
}
