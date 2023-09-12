const builtin = @import("builtin");
const std = @import("std");

const config = @import("config.zig");
const value = @import("value.zig");
const memory = @import("memory.zig");
const minor_gc = @import("minor_gc.zig");
const major_gc = @import("major_gc.zig");
const fiber = @import("fiber.zig");
const shared_heap = @import("shared_heap.zig");
const event = @import("event.zig");
const misc = @import("misc.zig");

comptime {
    @export(max_num_domain, .{ .name = "caml_max_num_domain" });
    @export(checkState, .{ .name = "caml_domain_check_state" });
    @export(alone, .{ .name = "caml_domain_alone" });
    @export(checkGcInterrupt, .{ .name = "caml_domain_check_gc_interrupt" });
    @export(incomingInterruptsQueued, .{ .name = "caml_domain_incoming_interrupts_queued" });
    @export(pollGcWork, .{ .name = "caml_domain_poll_gc_work" });
    @export(handleGcInterrupt, .{ .name = "caml_domain_handle_gc_interrupt" });
}

pub const max_num_domain: usize =
    if (@bitSizeOf(usize) == 64) 128 else 16;

pub var minor_heaps_start: usize =
    undefined;
pub var minor_heaps_end: usize =
    undefined;

pub const State = struct {
    young_limit: std.atomic.Atomic(usize) align(8),
    young_ptr: [*]value.Value align(8),
    young_start: [*]value.Value align(8),
    young_end: [*]value.Value align(8),
    young_trigger: [*]value.Value align(8),
    current_stack: *fiber.Stack align(8),
    action_pending: bool align(8),
    c_stack: ?*fiber.CStack align(8),
    minor_tables: *minor_gc.Tables align(8),
    marking_done: bool align(8),
    sweeping_done: bool align(8),
    allocated_words: usize align(8),
    major_slice_epoch: usize align(8),
    local_roots: ?*const memory.Roots align(8),
    requested_major_slice: bool align(8),
    requested_global_major_slice: bool align(8),
    requested_minor_gc: bool align(8),
    requested_external_interrupt: std.atomic.Atomic(bool) align(8),
    minor_heap_wsize: usize align(8),
    shared_heap: *shared_heap.State align(8),
    id: usize align(8),
    inside_stw_handler: bool align(8),
};
pub threadlocal var state: ?*State =
    null;

const Interruptor = struct {
    interrupt_word: std.atomic.Atomic(usize),
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,

    running: bool,
    terminating: isize,
    id: usize,

    interrupt_pending: std.atomic.Atomic(bool),
};

const Internal = struct {
    id: isize,
    state: *State,
    interruptor: Interruptor,

    backup_thread_running: bool,
    backup_thread: std.Thread,
    backup_thread_msg: std.atomic.Atomic(usize),
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,

    minor_heap_area_start: usize,
    minor_heap_area_end: usize,
};
threadlocal var internal: ?*Internal =
    null;

const StwRequest = struct {
    domains_still_running: std.atomic.Atomic(usize),
    num_domain_still_processing: std.atomic.Atomic(usize),
    callback: ?*const fn (*State, *anyopaque, usize, [*]?*State) void,
    data: ?*anyopaque,
    enter_spin_callback: ?*const fn (*State, *anyopaque) void,
    enter_spin_data: ?*anyopaque,

    num_domain: usize,
    barrier: std.atomic.Atomic(usize),

    participating: [max_num_domain]?*State,
};
var stw_request = StwRequest{
    .domains_still_running = std.atomic.Atomic(usize).init(0),
    .num_domain_still_processing = std.atomic.Atomic(usize).init(0),
    .callback = null,
    .data = null,
    .enter_spin_callback = null,
    .enter_spin_data = null,

    .num_domain = 0,
    .barrier = std.atomic.Atomic(usize).init(0),

    .participating = [1]?*State{null} ** max_num_domain,
};

var all_domains_mutex =
    std.Thread.Mutex{};
var all_domains_condition =
    std.Thread.Condition{};
var stw_leader =
    std.atomic.Atomic(usize).init(0);
var all_domains: [max_num_domain]Internal =
    undefined;

var num_domain_running =
    std.atomic.Atomic(usize).init(undefined);

const StwDomains = struct {
    num_participating: usize,
    internals: [max_num_domain]?*Internal,
};
var stw_domains = StwDomains{
    .num_participating = 0,
    .internals = [1]?*Internal{null} ** max_num_domain,
};

pub fn checkState() callconv(.C) void {
    if (state == null) {
        misc.fatalError("no domain lock held");
    }
}

pub fn alone() callconv(.C) bool {
    return num_domain_running.load(.Acquire) == 1;
}

pub fn checkGcInterrupt(state_: *State) callconv(.C) bool {
    misc.allocPoint();
    const young_limit = state_.young_limit.load(.Monotonic);
    if (@intFromPtr(state_.young_ptr) < young_limit) {
        @fence(.Acquire);
        return true;
    } else {
        return false;
    }
}

fn interrupt(interruptor: *Interruptor) void {
    interruptor.interrupt_word.store(std.math.maxInt(usize), .Release);
}

pub fn incomingInterruptsQueued() callconv(.C) bool {
    return internal.?.interruptor.interrupt_pending.load(.Acquire);
}

fn initialize_hook_default() void {
    return;
}
pub var initialize_hook =
    &initialize_hook_default;

fn stop_hook_default() void {
    return;
}
pub var stop_hook =
    &stop_hook_default;

fn external_interrupt_hook_default() void {
    return;
}
pub var external_interrupt_hook =
    &external_interrupt_hook_default;

fn decrementStwDomainsStillProcessing() void {
    if (stw_request.num_domain_still_processing.fetchSub(1, .SeqCst) == 1) {
        all_domains_mutex.lock();
        defer all_domains_mutex.unlock();

        stw_leader.store(0, .Release);
        all_domains_condition.broadcast();
        misc.gcLog("clearing STW leader");
    }
}

fn stwHandler(state_: *State) void {
    {
        event.begin(.stw_handler);
        defer event.end(.stw_handler);

        {
            event.begin(.stw_api_barrier);
            defer event.end(.stw_api_barrier);

            while (true) {
                if (stw_request.domains_still_running.load(.Acquire) == 0) {
                    break;
                }
                if (stw_request.enter_spin_callback) |enter_spin_callback| {
                    enter_spin_callback(state_, stw_request.enter_spin_data.?);
                }
                std.atomic.spinLoopHint();
            }
        }

        if (builtin.mode == .Debug) {
            state.?.inside_stw_handler = true;
        }
        stw_request.callback.?(state_, stw_request.data.?, stw_request.num_domain, &stw_request.participating);
        if (builtin.mode == .Debug) {
            state.?.inside_stw_handler = false;
        }

        decrementStwDomainsStillProcessing();
    }

    pollGcWork();
}

pub fn inStw() bool {
    return state.?.inside_stw_handler;
}

// TODO
pub fn tryRunOnAllDomainsWithSpinWork(sync: bool, handler: *const fn (*State, *anyopaque, usize, [*]*State) void, data: ?*anyopaque, leader_setup: *const fn (*State) void, enter_spin_callback: *const fn (*State, ?*anyopaque) void, enter_spin_data: ?*anyopaque) bool {
    _ = sync;
    _ = handler;
    _ = data;
    _ = leader_setup;
    _ = enter_spin_callback;
    _ = enter_spin_data;
    return undefined;
}

fn handleIncomingInterrupts(interruptor: *Interruptor) bool {
    const handled = interruptor.interrupt_pending.load(.Acquire);
    std.debug.assert(interruptor.running);
    if (handled) {
        interruptor.interrupt_pending.store(false, .Release);
        stwHandler(internal.?.state);
    }
    return handled;
}

// TODO
fn tryRunOnAllDomainsAsync(handler: *const fn (*State, *anyopaque, []*State) void, data: ?*anyopaque, leader_setup: ?*const fn (*State) void) bool {
    _ = handler;
    _ = data;
    _ = leader_setup;
    return undefined;
}

fn resetYoungLimit(state_: *State) void {
    std.debug.assert(@intFromPtr(state_.young_trigger) < @intFromPtr(state_.young_ptr));
    _ = state_.young_limit.swap(@intFromPtr(state_.young_trigger), .SeqCst);
    const internal_ = &all_domains[state_.id];
    if (internal_.interruptor.interrupt_pending.load(.Monotonic) or
        state_.requested_minor_gc or
        state_.requested_major_slice or
        state_.major_slice_epoch < minor_gc.major_slice_epoch.load(.SeqCst) or
        state_.requested_external_interrupt.load(.Monotonic) or
        state_.action_pending)
    {
        state_.young_limit.store(std.math.maxInt(usize), .Release);
        std.debug.assert(checkGcInterrupt(state_));
    }
}

fn advanceGlobalMajorSliceEpoch(state_: *State) void {
    std.debug.assert(minor_gc.major_slice_epoch.load(.SeqCst) <= minor_gc.num_collection.load(.SeqCst));

    const old = minor_gc.major_slice_epoch.swap(minor_gc.num_collection.load(.SeqCst), .SeqCst);

    if (old != minor_gc.num_collection.load(.SeqCst)) {
        if (all_domains_mutex.tryLock()) {
            defer all_domains_mutex.unlock();

            for (0..stw_domains.num_participating) |i| {
                const internal_ = stw_domains.internals[i].?;
                if (internal_.state != state_) {
                    interrupt(&internal_.interruptor);
                }
            }
        }
    }
}

fn globalMajorSliceCallback(state_: *State, unused: *anyopaque, participating: []*State) void {
    state_.requested_major_slice = true;
    _ = unused;
    _ = participating;
}

pub fn pollGcWork() callconv(.C) void {
    misc.allocPoint();

    const state_ = state.?;

    if (@intFromPtr(state_.young_ptr - config.max_young_wsize - value.header_wsize) < @intFromPtr(state_.young_trigger)) {
        if (state_.young_trigger == state_.young_start) {
            state_.requested_minor_gc = true;
        } else {
            std.debug.assert(state_.young_trigger == state_.young_start + (@intFromPtr(state_.young_end) - @intFromPtr(state_.young_start)) / 2);
            advanceGlobalMajorSliceEpoch(state_);
            state_.young_trigger = state_.young_start;
        }
    } else if (state_.requested_minor_gc) {
        advanceGlobalMajorSliceEpoch(state_);
    }

    if (state_.major_slice_epoch < minor_gc.major_slice_epoch.load(.SeqCst)) {
        state_.requested_major_slice = true;
    }

    if (state_.requested_minor_gc) {
        state_.requested_minor_gc = false;
        minor_gc.emptyMinorHeapsOnce();
    }

    if (state_.requested_major_slice or state_.requested_global_major_slice) {
        event.begin(.major);
        defer event.end(.major);

        state_.requested_major_slice = false;
        major_gc.majorCollectionSlice(major_gc.auto_triggered_major_slice);
    }

    if (state_.requested_global_major_slice) {
        if (tryRunOnAllDomainsAsync(globalMajorSliceCallback, null, null)) {
            state_.requested_global_major_slice = false;
        }
    }

    if (state_.requested_external_interrupt.load(.Acquire)) {
        external_interrupt_hook();
    }
    resetYoungLimit(state_);
}

pub fn handleGcInterrupt() callconv(.C) void {
    misc.allocPoint();
    if (incomingInterruptsQueued()) {
        event.begin(.interrupt_remote);
        defer event.end(.interrupt_remote);

        _ = handleIncomingInterrupts(&internal.?.interruptor);
    }
    pollGcWork();
}
