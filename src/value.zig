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
pub const Exception =
    isize;

pub export const header_wsize: usize =
    @sizeOf(Header) / @sizeOf(usize);
pub export const header_bitsize: usize =
    @sizeOf(Header) * 8;

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
pub export const tag_string: Tag =
    252;

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

pub export fn isInt(v: Value) bool {
    return (v & 1) != 0;
}
pub export fn isBlock(v: Value) bool {
    return (v & 1) == 0;
}
pub export fn isYoung(v: Value) bool {
    std.debug.assert(isBlock(v));
    return @as(usize, @bitCast(v)) < domain.minor_heaps_end and domain.minor_heaps_start < @as(usize, @bitCast(v));
}

pub export fn ofInt(i: isize) Value {
    return @as(isize, @bitCast(@as(usize, @bitCast(i)) << 1)) + 1;
}
pub export fn toInt(v: Value) isize {
    std.debug.assert(isInt(v));
    return v >> 1;
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
pub export fn setField(blk: Value, i: usize, v: Value) void {
    @atomicStore(Value, fieldPtr(blk, i), v, .Unordered);
}

pub export fn bytes(blk: Value) [*]u8 {
    return @ptrCast(fields(blk));
}
pub export fn bytePtr(blk: Value, i: usize) *u8 {
    return @ptrCast(bytes(blk) + i);
}
pub export fn byte(blk: Value, i: usize) u8 {
    return @atomicLoad(u8, bytePtr(blk, i), .Unordered);
}
pub export fn setByte(blk: Value, i: usize, byt: u8) void {
    @atomicStore(u8, bytePtr(blk, i), byt, .Unordered);
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

pub export fn makeException(v: Value) Value {
    return v | 2;
}
pub export fn isException(v: Value) bool {
    return v & 3 == 2;
}
pub export fn exception(v: Value) Exception {
    return v & ~@as(Value, 3);
}

pub export const unit =
    ofInt(0);
