levels: std.bit_set.IntegerBitSet(N) = .initEmpty(),
len: std.math.IntFittingRange(0, N) = 0,

const N = 32;
const std = @import("std");
const Writer = std.Io.Writer;

pub const empty = @This(){};

const pattern_a: [4]u8 = [4]u8{ 0xe2, 0x80, 0x80, 0x20 }; // "\xe2\x80\x80 "
const pattern_b: [4]u8 = [4]u8{ 0xe2, 0x94, 0x82, 0x20 }; // "│ "

pub fn writeUtf8Prefix(
    w: *Writer,
    bits: std.bit_set.IntegerBitSet(N),
    len: std.math.IntFittingRange(0, N),
) !void {
    const n = @as(usize, @intCast(len)) * 4;
    const buffer = try w.writableSlice(n);
    for (0..len) |i| {
        const pattern = if (bits.isSet(i)) &pattern_b else &pattern_a;
        @memcpy(buffer[i * 4 ..][0..4], pattern);
    }
}

pub fn show(self: @This(), writer: *Writer, more: bool) !void {
    try writeUtf8Prefix(writer, self.levels, self.len);
    if (self.len > 0) {
        try writer.writeAll(if (!more) "└─" else "├─");
    }
}

pub fn push(self: *@This(), more: bool) !void {
    if (self.len + 1 >= N) return error.OutOfMemory;
    self.levels.setValue(self.len, more);
    self.len += 1;
}

pub fn pop(self: *@This()) void {
    self.len -= 1;
}

export fn bench(buf: [*]u8, bits: [*]const u8, len: u32) void {
    var w = std.Io.Writer.fixed(buf[0..1024]);
    var bitset = std.bit_set.IntegerBitSet(N).initEmpty();
    for (0..@min(len, N)) |i| {
        bitset.setValue(i, bits[i] != 0);
    }
    writeUtf8Prefix(&w, bitset, @intCast(len)) catch unreachable;
}

test "hehe" {
    var buffer: [1024]u8 = undefined;
    var w = std.Io.Writer.fixed(&buffer);
    var bits = std.bit_set.IntegerBitSet(N).initEmpty();
    bits.set(0);
    bits.set(3);

    try writeUtf8Prefix(&w, bits, 4);
    try std.testing.expectEqualStrings("│ \xe2\x80\x80 \xe2\x80\x80 │ ", w.buffered());
}

test "hehe 2" {
    var buffer: [1024]u8 = undefined;
    var w = std.Io.Writer.fixed(&buffer);

    var tree = @This().empty;
    try tree.push(true);
    try tree.push(false);
    try tree.push(false);
    try tree.push(true);
    try tree.show(&w, true);

    try std.testing.expectEqualStrings("│ \xe2\x80\x80 \xe2\x80\x80 │ ├─", w.buffered());
}
