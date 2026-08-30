const std = @import("std");
const p = @import("pretty.zig");

const Parser = struct {
    tree: *p.Tree,
    input: []const u8,
    pos: usize = 0,
    depth: u8 = 0,

    fn byte(self: *Parser) !u8 {
        if (self.pos == self.input.len) return error.UnexpectedEnd;
        defer self.pos += 1;
        return self.input[self.pos];
    }

    fn argument(self: *Parser, info: u5) !?u64 {
        return switch (info) {
            0...23 => info,
            24 => try self.byte(),
            25 => try self.readInt(u16),
            26 => try self.readInt(u32),
            27 => try self.readInt(u64),
            31 => null,
            else => error.InvalidCbor,
        };
    }

    fn readInt(self: *Parser, comptime T: type) !T {
        const size = @sizeOf(T);
        if (self.input.len - self.pos < size) return error.UnexpectedEnd;
        const decoded = std.mem.readInt(T, self.input[self.pos..][0..size], .big);
        self.pos += size;
        return decoded;
    }

    fn bytes(self: *Parser, len: u64) ![]const u8 {
        const n: usize = std.math.cast(usize, len) orelse return error.InputTooLarge;
        if (self.input.len - self.pos < n) return error.UnexpectedEnd;
        defer self.pos += n;
        return self.input[self.pos..][0..n];
    }

    fn value(self: *Parser) anyerror!p.Node {
        if (self.depth == 128) return error.TooDeep;
        self.depth += 1;
        defer self.depth -= 1;

        const initial = try self.byte();
        const major = initial >> 5;
        const arg = try self.argument(@truncate(initial));
        return switch (major) {
            0 => self.tree.format("{d}", .{arg orelse return error.InvalidCbor}),
            1 => self.negative(arg orelse return error.InvalidCbor),
            2 => self.byteString(arg),
            3 => self.textString(arg),
            4 => self.array(arg),
            5 => self.map(arg),
            6 => blk: {
                _ = arg orelse return error.InvalidCbor;
                break :blk try self.value();
            },
            7 => self.simple(@truncate(initial), arg),
            else => unreachable,
        };
    }

    fn negative(self: *Parser, n: u64) !p.Node {
        if (n == std.math.maxInt(u64)) return self.tree.text("-18446744073709551616");
        return self.tree.format("-{d}", .{n + 1});
    }

    fn byteString(self: *Parser, len: ?u64) !p.Node {
        if (len == null) return error.UnsupportedIndefiniteString;
        const data = try self.bytes(len.?);
        var nodes: std.ArrayList(p.Node) = .empty;
        defer nodes.deinit(self.tree.bank);
        for (data) |b| try nodes.append(self.tree.bank, try self.tree.format("{d}", .{b}));
        return jsonContainer(self.tree, nodes.items, "[", "]");
    }

    fn textString(self: *Parser, len: ?u64) !p.Node {
        if (len == null) return error.UnsupportedIndefiniteString;
        const text = try self.bytes(len.?);
        if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
        return jsonString(self.tree, text);
    }

    fn array(self: *Parser, len: ?u64) !p.Node {
        var nodes: std.ArrayList(p.Node) = .empty;
        defer nodes.deinit(self.tree.bank);
        if (len) |count| {
            const n: usize = std.math.cast(usize, count) orelse return error.InputTooLarge;
            try nodes.ensureTotalCapacity(self.tree.bank, n);
            for (0..n) |_| nodes.appendAssumeCapacity(try self.value());
        } else {
            while (!try self.takeBreak()) try nodes.append(self.tree.bank, try self.value());
        }
        return jsonContainer(self.tree, nodes.items, "[", "]");
    }

    fn map(self: *Parser, len: ?u64) !p.Node {
        var fields: std.ArrayList(p.Node) = .empty;
        defer fields.deinit(self.tree.bank);
        if (len) |count| {
            const n: usize = std.math.cast(usize, count) orelse return error.InputTooLarge;
            try fields.ensureTotalCapacity(self.tree.bank, n);
            for (0..n) |_| fields.appendAssumeCapacity(try self.field());
        } else {
            while (!try self.takeBreak()) try fields.append(self.tree.bank, try self.field());
        }
        return jsonContainer(self.tree, fields.items, "{", "}");
    }

    fn field(self: *Parser) !p.Node {
        const initial = try self.byte();
        if (initial >> 5 != 3) return error.NonStringMapKey;
        const len = (try self.argument(@truncate(initial))) orelse return error.UnsupportedIndefiniteString;
        const key = try self.bytes(len);
        if (!std.unicode.utf8ValidateSlice(key)) return error.InvalidUtf8;
        return self.tree.cat(&.{
            try jsonString(self.tree, key),
            try self.tree.text(": "),
            try self.value(),
        });
    }

    fn simple(self: *Parser, info: u5, arg: ?u64) !p.Node {
        return switch (info) {
            20 => self.tree.text("false"),
            21 => self.tree.text("true"),
            22, 23 => self.tree.text("null"),
            25 => self.float(@as(f64, @floatCast(@as(f16, @bitCast(@as(u16, @intCast(arg.?))))))),
            26 => self.float(@as(f64, @floatCast(@as(f32, @bitCast(@as(u32, @intCast(arg.?))))))),
            27 => self.float(@as(f64, @bitCast(arg.?))),
            31 => error.UnexpectedBreak,
            else => error.UnsupportedSimpleValue,
        };
    }

    fn float(self: *Parser, number: f64) !p.Node {
        if (!std.math.isFinite(number)) return error.NonFiniteFloat;
        return self.tree.format("{d}", .{number});
    }

    fn takeBreak(self: *Parser) !bool {
        if (self.pos == self.input.len) return error.UnexpectedEnd;
        if (self.input[self.pos] != 0xff) return false;
        self.pos += 1;
        return true;
    }
};

fn jsonString(tree: *p.Tree, text: []const u8) !p.Node {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(tree.bank);
    try out.append(tree.bank, '"');
    for (text) |c| switch (c) {
        '"' => try out.appendSlice(tree.bank, "\\\""),
        '\\' => try out.appendSlice(tree.bank, "\\\\"),
        '\x08' => try out.appendSlice(tree.bank, "\\b"),
        '\x0c' => try out.appendSlice(tree.bank, "\\f"),
        '\n' => try out.appendSlice(tree.bank, "\\n"),
        '\r' => try out.appendSlice(tree.bank, "\\r"),
        '\t' => try out.appendSlice(tree.bank, "\\t"),
        else => if (c < 0x20) {
            var buf: [6]u8 = undefined;
            const escaped = try std.fmt.bufPrint(&buf, "\\u00{X:0>2}", .{c});
            try out.appendSlice(tree.bank, escaped);
        } else try out.append(tree.bank, c),
    };
    try out.append(tree.bank, '"');
    const z = try out.toOwnedSliceSentinel(tree.bank, 0);
    defer tree.bank.free(z);
    return tree.text(z);
}

fn jsonContainer(tree: *p.Tree, items: []const p.Node, open: [:0]const u8, close: [:0]const u8) !p.Node {
    if (items.len == 0) return tree.cat(&.{ try tree.text(open), try tree.text(close) });
    const comma = try tree.text(",");
    var lines: std.ArrayList(p.Node) = .empty;
    defer lines.deinit(tree.bank);
    for (items, 0..) |item, i| {
        try lines.append(tree.bank, if (i + 1 == items.len) item else try tree.plus(item, comma));
    }
    const block = try tree.pile(&.{
        try tree.nest(2, try tree.pile(&.{ try tree.text(open), try tree.pile(lines.items) })),
        try tree.text(close),
    });
    return tree.fork(block, try tree.flat(block));
}

pub fn parse(tree: *p.Tree, input: []const u8) !p.Node {
    var parser: Parser = .{ .tree = tree, .input = input };
    const node = try parser.value();
    if (parser.pos != input.len) return error.TrailingData;
    return node;
}

test "CBOR becomes formatted JSON" {
    // {"name":"zoot","ok":true,"values":[1,2,3]}
    const input = [_]u8{ 0xa3, 0x64, 'n', 'a', 'm', 'e', 0x64, 'z', 'o', 'o', 't', 0x62, 'o', 'k', 0xf5, 0x66, 'v', 'a', 'l', 'u', 'e', 's', 0x83, 1, 2, 3 };
    var tree = try p.Tree.init(std.testing.allocator);
    defer tree.deinit();
    const doc = try parse(&tree, &input);
    const best = try @import("recursive.zig").pickWithOptions(&tree, std.testing.allocator, p.F2.init(20), doc, .{});
    var buffer: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try tree.emit(&writer, best.idea.node);
    try std.testing.expectEqualStrings(
        "{\n  \"name\": \"zoot\",\n  \"ok\": true,\n  \"values\": [\n    1,\n    2,\n    3\n  ]\n}",
        writer.buffered(),
    );
}
