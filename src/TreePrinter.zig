levels: Bits = if (use_bool_vector) @splat(false) else @splat(0),
len: std.math.IntFittingRange(0, N) = 0,

const N = 32;
const builtin = @import("builtin");

// Use packed bool vector on AVX-512 (optimal with mask registers),
// but use u8 vector on other platforms to avoid scalar bit extraction
const use_bool_vector = builtin.cpu.arch == .x86_64 and
    std.Target.x86.featureSetHas(builtin.cpu.features, .avx512f);

const BitsType = if (use_bool_vector) bool else u8;
const Bits = @Vector(N, BitsType);

const std = @import("std");
const Writer = std.Io.Writer;

pub const empty = @This(){};

const av: @Vector(4, u8) = "  "[0..4].*;
const bv: @Vector(4, u8) = "│ "[0..4].*;
const au: u32 = @bitCast(av);
const bu: u32 = @bitCast(bv);
const aa: @Vector(N, u32) = @splat(au);
const bb: @Vector(N, u32) = @splat(bu);

pub fn writeUtf8Prefix(
    w: *Writer,
    bits: Bits,
    len: std.math.IntFittingRange(0, N),
) !void {
    const mask: @Vector(N, bool) = if (use_bool_vector)
        bits
    else
        bits != @as(@Vector(N, u8), @splat(0));
    const sv = @select(u32, mask, bb, aa);
    const bytes: [4 * N]u8 = @bitCast(sv);
    const byte_len: usize = @as(usize, len) * 4;
    try w.writeAll(bytes[0..byte_len]);
}

pub fn show(self: @This(), writer: *Writer, more: bool) !void {
    try writeUtf8Prefix(writer, self.levels, self.len);
    if (self.len > 0) {
        try writer.writeAll(if (!more) "└─" else "├─");
    }
}

pub fn push(self: *@This(), more: bool) !void {
    if (self.len + 1 >= N) return error.OutOfMemory; // lol
    self.levels[self.len] = if (use_bool_vector) more else @intFromBool(more);
    self.len += 1;
}

pub fn pop(self: *@This()) void {
    self.len -= 1;
}

test "hehe" {
    var buffer: [1024]u8 = undefined;
    var w = std.Io.Writer.fixed(&buffer);
    var bits: Bits = if (use_bool_vector) @splat(false) else @splat(0);
    bits[0] = if (use_bool_vector) true else 1;
    bits[3] = if (use_bool_vector) true else 1;

    try writeUtf8Prefix(&w, bits, 4);
    try std.testing.expectEqualStrings("│     │ ", w.buffered());
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

    try std.testing.expectEqualStrings("│     │ ├─", w.buffered());
}
