const std = @import("std");

const domain = @import("domain.zig");

comptime {
    @export(header_wsize, .{ .name = "caml_value_header_wsize" });
    @export(header_bitsize, .{ .name = "caml_value_header_bitsize" });
    @export(reserved_bitsize, .{ .name = "caml_value_reserved_bitsize" });
    @export(reserved_shift, .{ .name = "caml_value_reserved_shift" });
    @export(tag_bitsize, .{ .name = "caml_value_tag_bitsize" });
    @export(tag_mask, .{ .name = "caml_value_tag_mask" });
    @export(tag_max, .{ .name = "caml_value_tag_max" });
    @export(tag_infix, .{ .name = "caml_value_tag_infix" });
    @export(tag_no_scan, .{ .name = "caml_value_tag_no_scan" });
    @export(tag_string, .{ .name = "caml_value_tag_string" });
    @export(color_bitsize, .{ .name = "caml_value_color_bitsize" });
    @export(color_shift, .{ .name = "caml_value_color_shift" });
    @export(color_mask, .{ .name = "caml_value_color_mask" });
    @export(color_not_markable, .{ .name = "caml_value_color_not_markable" });
    @export(size_bitsize, .{ .name = "caml_value_size_bitsize" });
    @export(size_shift, .{ .name = "caml_value_size_shift" });
    @export(size_mask, .{ .name = "caml_value_size_mask" });
    @export(size_max, .{ .name = "caml_value_size_max" });
    @export(isInt, .{ .name = "caml_value_is_int" });
    @export(isBlock, .{ .name = "caml_value_is_block" });
    @export(isYoung, .{ .name = "caml_value_is_young" });
    @export(ofInt, .{ .name = "caml_value_of_int" });
    @export(toInt, .{ .name = "caml_value_to_int" });
    @export(ofFields, .{ .name = "caml_value_of_fields" });
    @export(fields, .{ .name = "caml_value_fields" });
    @export(fieldPtr, .{ .name = "caml_value_field_ptr" });
    @export(field, .{ .name = "caml_value_field" });
    @export(setField, .{ .name = "caml_value_set_field" });
    @export(bytes, .{ .name = "caml_value_bytes" });
    @export(bytePtr, .{ .name = "caml_value_byte_ptr" });
    @export(byte, .{ .name = "caml_value_byte" });
    @export(setByte, .{ .name = "caml_value_set_byte" });
    @export(ofHeaderPtr, .{ .name = "caml_value_of_header_ptr" });
    @export(headerPtr, .{ .name = "caml_value_header_ptr" });
    @export(header, .{ .name = "caml_value_header" });
    @export(headerTag, .{ .name = "caml_value_header_tag" });
    @export(headerWithTag, .{ .name = "caml_value_header_with_tag" });
    @export(headerColor, .{ .name = "caml_value_header_color" });
    @export(color, .{ .name = "caml_value_color" });
    @export(headerWithColor, .{ .name = "caml_value_header_with_color" });
    @export(headerSize, .{ .name = "caml_value_header_size" });
    @export(size, .{ .name = "caml_value_size" });
    @export(headerOfReserved, .{ .name = "caml_value_header_of_reserved" });
    @export(headerMakeWithReserved, .{ .name = "caml_value_header_make_with_reserved" });
    @export(headerMake, .{ .name = "caml_value_header_make" });
    @export(makeException, .{ .name = "caml_value_make_exception" });
    @export(isException, .{ .name = "caml_value_is_exception" });
    @export(exception, .{ .name = "caml_value_exception" });
    @export(unit, .{ .name = "caml_value_unit" });
}

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

pub const header_wsize: usize =
    @sizeOf(Header) / @sizeOf(usize);
pub const header_bitsize: usize =
    @sizeOf(Header) * 8;

pub const reserved_bitsize: usize =
    0;
pub const reserved_shift: usize =
    header_bitsize - reserved_bitsize;

pub const tag_bitsize: usize =
    8;
pub const tag_mask: Header =
    (1 << tag_bitsize) - 1;
pub const tag_max: Tag =
    (1 << tag_bitsize) - 1;
pub const tag_infix: Tag =
    249;
pub const tag_no_scan: Tag =
    251;
pub const tag_string: Tag =
    252;

pub const color_bitsize: usize =
    2;
pub const color_shift: usize =
    tag_bitsize;
pub const color_mask: Header =
    ((1 << color_bitsize) - 1) << color_shift;
pub const color_not_markable: Color =
    3 << color_shift;

pub const size_bitsize: usize =
    header_bitsize - tag_bitsize - color_bitsize - reserved_bitsize;
pub const size_shift: usize =
    color_shift + color_bitsize;
pub const size_mask: Header =
    ((1 << size_bitsize) - 1) << size_shift;
pub const size_max: usize =
    (1 << size_bitsize) - 1;

pub fn isInt(v: Value) callconv(.C) bool {
    return (v & 1) != 0;
}
pub fn isBlock(v: Value) callconv(.C) bool {
    return (v & 1) == 0;
}
pub fn isYoung(v: Value) callconv(.C) bool {
    std.debug.assert(isBlock(v));
    return @as(usize, @bitCast(v)) < domain.minor_heaps_end and domain.minor_heaps_start < @as(usize, @bitCast(v));
}

pub fn ofInt(i: isize) callconv(.C) Value {
    return @as(isize, @bitCast(@as(usize, @bitCast(i)) << 1)) + 1;
}
pub fn toInt(v: Value) callconv(.C) isize {
    std.debug.assert(isInt(v));
    return v >> 1;
}

pub fn ofFields(flds: [*]Value) callconv(.C) Value {
    return @bitCast(@intFromPtr(flds));
}
pub fn fields(blk: Value) callconv(.C) [*]Value {
    std.debug.assert(isBlock(blk));
    return @ptrFromInt(@as(usize, @bitCast(blk)));
}
pub fn fieldPtr(blk: Value, i: usize) callconv(.C) *Value {
    return @ptrCast(fields(blk) + i);
}
pub fn field(blk: Value, i: usize) callconv(.C) Value {
    return @atomicLoad(Value, fieldPtr(blk, i), .Unordered);
}
pub fn setField(blk: Value, i: usize, v: Value) callconv(.C) void {
    @atomicStore(Value, fieldPtr(blk, i), v, .Unordered);
}

pub fn bytes(blk: Value) callconv(.C) [*]u8 {
    return @ptrCast(fields(blk));
}
pub fn bytePtr(blk: Value, i: usize) callconv(.C) *u8 {
    return @ptrCast(bytes(blk) + i);
}
pub fn byte(blk: Value, i: usize) callconv(.C) u8 {
    return @atomicLoad(u8, bytePtr(blk, i), .Unordered);
}
pub fn setByte(blk: Value, i: usize, byt: u8) callconv(.C) void {
    @atomicStore(u8, bytePtr(blk, i), byt, .Unordered);
}

pub fn ofHeaderPtr(hdr: *Header) callconv(.C) Value {
    return @bitCast(@intFromPtr(@as([*]Header, @ptrCast(hdr)) + 1));
}
pub fn headerPtr(blk: Value) callconv(.C) *Header {
    std.debug.assert(isBlock(blk));
    return @ptrCast(@as([*]Header, @ptrFromInt(@as(usize, @bitCast(blk)))) - 1);
}
pub fn header(blk: Value) callconv(.C) Header {
    return @atomicLoad(Header, headerPtr(blk), .Unordered);
}

pub fn headerTag(hdr: Header) callconv(.C) Tag {
    return hdr & tag_mask;
}
pub fn headerWithTag(hdr: Header, tag: Tag) callconv(.C) Header {
    return (hdr & ~tag_mask) | tag;
}

pub fn headerColor(hdr: Header) callconv(.C) Color {
    return hdr & color_mask;
}
pub fn color(blk: Value) callconv(.C) Color {
    return headerColor(header(blk));
}
pub fn headerWithColor(hdr: Header, col: Color) callconv(.C) Header {
    return (hdr & ~color_mask) | col;
}

pub fn headerSize(hdr: Header) callconv(.C) usize {
    return (hdr & size_mask) >> size_shift;
}
pub fn size(blk: Value) callconv(.C) usize {
    return headerSize(header(blk));
}

pub fn headerOfReserved(rsv: Reserved) callconv(.C) Header {
    return if (reserved_bitsize == 0) 0 else @as(Header, rsv) << reserved_shift;
}

pub fn headerMakeWithReserved(sz: usize, tag: Tag, col: Color, rsv: Reserved) callconv(.C) Header {
    std.debug.assert(sz <= size_max);
    return headerOfReserved(rsv) + (@as(Header, sz) << size_shift) + col + tag;
}
pub fn headerMake(sz: usize, tag: Tag, col: Color) callconv(.C) Header {
    return headerMakeWithReserved(sz, tag, col, 0);
}

pub fn makeException(v: Value) callconv(.C) Value {
    return v | 2;
}
pub fn isException(v: Value) callconv(.C) bool {
    return v & 3 == 2;
}
pub fn exception(v: Value) callconv(.C) Exception {
    return v & ~@as(Value, 3);
}

pub const unit =
    ofInt(0);
