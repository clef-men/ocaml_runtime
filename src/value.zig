const std = @import("std");

const domain = @import("domain.zig");

pub const Value =
    isize;
pub const Header =
    usize;
pub const Tag =
    usize;
pub const Color =
    usize;
pub const Reserved =
    usize;

pub export const header_bytsize: usize =
    @sizeOf(Header);
pub export const header_wsize: usize =
    header_bytsize / @sizeOf(usize);
pub export const header_bitsize: usize =
    header_bytsize * 8;

pub export const reserved_bitsize: usize =
    0;
pub export const reserved_shift: usize =
    header_bitsize - reserved_bitsize;

pub export const tag_bitsize: usize =
    8;
pub export const tag_mask: Header =
    (1 << tag_bitsize) - 1;
pub export const tag_max: Tag =
    (1 << tag_bitsize) - 1;
pub export const tag_infix: Tag =
    249;
pub export const tag_no_scan: Tag =
    251;

pub export const color_bitsize: usize =
    2;
pub export const color_shift: usize =
    tag_bitsize;
pub export const color_mask: Header =
    ((1 << color_bitsize) - 1) << color_shift;
pub export const color_not_markable: Color =
    3 << color_shift;

pub export const size_bitsize: usize =
    header_bitsize - tag_bitsize - color_bitsize - reserved_bitsize;
pub export const size_shift: usize =
    color_shift + color_bitsize;
pub export const size_mask: Header =
    ((1 << size_bitsize) - 1) << size_shift;
pub export const size_max: usize =
    (1 << size_bitsize) - 1;

pub export fn isInt(val: Value) bool {
    return (val & 1) != 0;
}
pub export fn isBlock(val: Value) bool {
    return (val & 1) == 0;
}
pub export fn isYoung(val: Value) bool {
    std.debug.assert(isBlock(val));
    return @as(usize, @bitCast(val)) < domain.minor_heaps_end and domain.minor_heaps_start < @as(usize, @bitCast(val));
}

pub export fn ofInt(i: isize) Value {
    return @as(isize, @bitCast(@as(usize, @bitCast(i)) << 1)) + 1;
}
pub export fn toInt(val: Value) isize {
    std.debug.assert(isInt(val));
    return val >> 1;
}

pub export fn ofFields(flds: [*]Value) Value {
    return @bitCast(@intFromPtr(flds));
}
pub export fn fields(blk: Value) [*]Value {
    std.debug.assert(isBlock(blk));
    return @ptrFromInt(@as(usize, @bitCast(blk)));
}
pub export fn fieldPtr(blk: Value, i: usize) *Value {
    return @ptrCast(fields(blk) + i);
}
pub export fn field(blk: Value, i: usize) Value {
    return @atomicLoad(Value, fieldPtr(blk, i), .Unordered);
}

pub export fn ofHeaderPtr(hdr: *Header) Value {
    return @bitCast(@intFromPtr(@as([*]Header, @ptrCast(hdr)) + 1));
}
pub export fn headerPtr(blk: Value) *Header {
    std.debug.assert(isBlock(blk));
    return @ptrCast(@as([*]Header, @ptrFromInt(@as(usize, @bitCast(blk)))) - 1);
}
pub export fn header(blk: Value) Header {
    return @atomicLoad(Header, headerPtr(blk), .Unordered);
}

pub export fn headerTag(hdr: Header) Tag {
    return hdr & tag_mask;
}
pub export fn headerWithTag(hdr: Header, tag: Tag) Header {
    return (hdr & ~tag_mask) | tag;
}

pub export fn headerColor(hdr: Header) Color {
    return hdr & color_mask;
}
pub export fn color(blk: Value) Color {
    return headerColor(header(blk));
}
pub export fn headerWithColor(hdr: Header, col: Color) Header {
    return (hdr & ~color_mask) | col;
}

pub export fn headerSize(hdr: Header) usize {
    return (hdr & size_mask) >> size_shift;
}
pub export fn size(blk: Value) usize {
    return headerSize(header(blk));
}

pub export fn headerOfReserved(rsv: Reserved) Header {
    return if (reserved_bitsize == 0) 0 else @as(Header, rsv) << reserved_shift;
}

pub export fn headerMakeWithReserved(sz: usize, tag: Tag, col: Color, rsv: Reserved) Header {
    std.debug.assert(sz <= size_max);
    return headerOfReserved(rsv) + (@as(Header, sz) << size_shift) + col + tag;
}
pub export fn headerMake(sz: usize, tag: Tag, col: Color) Header {
    return headerMakeWithReserved(sz, tag, col, 0);
}

pub export const unit =
    ofInt(0);
