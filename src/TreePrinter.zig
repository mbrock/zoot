levels: Bits = @splat(false),
len: std.math.IntFittingRange(0, N) = 0,

const N = 32;
const Bits = @Vector(N, bool);

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
    bits: @Vector(N, bool),
    len: std.math.IntFittingRange(0, N),
) !void {
    const sv = @select(u32, bits, bb, aa);
    const bytes: [4 * N]u8 = @bitCast(sv);
    try w.writeAll(bytes[0 .. len * 4]);
}

pub fn show(self: @This(), writer: *Writer, more: bool) !void {
    try writeUtf8Prefix(writer, self.levels, self.len);
    if (self.len > 0) {
        try writer.writeAll(if (!more) "└─" else "├─");
    }
}

pub fn push(self: *@This(), more: bool) !void {
    if (self.len + 1 >= N) return error.OutOfMemory; // lol
    self.levels[self.len] = more;
    self.len += 1;
}

pub fn pop(self: *@This()) void {
    self.len -= 1;
}

test "hehe" {
    var buffer: [1024]u8 = undefined;
    var w = std.Io.Writer.fixed(&buffer);
    var bits: Bits = @splat(false);
    bits[0] = true;
    bits[3] = true;

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

// pub fn print(self: @This(), writer: *Writer, last: bool) !void {
//     var level: usize = 0;
//     while (level + 1 < self.len) : (level += 1) {
//         const bit = self.levels.isSet(level);
//         try writer.writeAll(if (bit) "│ " else "  ");
//     }
//     if (depth > 0) {
//         try writer.writeAll(if (last) "└─" else "├─");
//     }
// }
//
// pub fn push(self: *TreePrinter, has_more: bool) !void {
//     try self.prefix.push(@intFromBool(has_more));
// }
//
// pub fn pop(self: *TreePrinter) void {
//     _ = self.prefix.pop();
// }
