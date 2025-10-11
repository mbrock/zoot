const std = @import("std");
const pretty = @import("pretty.zig");

const Node = pretty.Node;
const Tree = pretty.Tree;

pub fn dump(tree: *Tree, value: anytype) !Node {
    return dumpTyped(tree, @TypeOf(value), value);
}

fn dumpTyped(tree: *Tree, comptime T: type, value: T) anyerror!Node {
    switch (@typeInfo(T)) {
        .bool => {
            return tree.format("{s}", .{if (value) "true" else "false"});
        },
        .void => {
            return tree.text("void");
        },
        .null => {
            return tree.text("null");
        },
        .int, .comptime_int => {
            return tree.format("{d}", .{value});
        },
        .float, .comptime_float => {
            return tree.format("{g}", .{value});
        },
        .type => {
            return tree.format("{s}", .{@typeName(value)});
        },
        .@"enum" => {
            return tree.format(".{s}", .{@tagName(value)});
        },
        .enum_literal => {
            return tree.format(".{s}", .{@tagName(value)});
        },
        .error_set => {
            return tree.format("error.{s}", .{@errorName(value)});
        },
        .optional => |info| {
            if (value) |payload| {
                return dumpTyped(tree, info.child, payload);
            }
            return tree.text("null");
        },
        .error_union => |info| {
            if (value) |payload| {
                return dumpTyped(tree, info.payload, payload);
            } else |err| {
                return tree.format("error.{s}", .{@errorName(err)});
            }
        },
        .@"struct" => |info| {
            if (info.is_tuple) {
                return dumpTuple(tree, info, value);
            }
            return dumpStruct(tree, info, value);
        },
        .@"union" => |info| {
            if (info.tag_type) |_| {
                return dumpTaggedUnion(tree, info, value);
            }
            return tree.format("union< {s} >", .{@typeName(T)});
        },
        .array => |info| {
            if (info.child == u8) {
                const slice = if (info.sentinel()) |sent|
                    std.mem.sliceTo(@as([]const u8, value[0..]), sent)
                else
                    value[0..];
                return dumpString(tree, slice);
            }
            return dumpArray(tree, value);
        },
        .vector => {
            return tree.format("vector< {s} >", .{@typeName(T)});
        },
        .pointer => |ptr| switch (ptr.size) {
            .slice => {
                if (ptr.child == u8) {
                    const slice: []const u8 = if (ptr.sentinel()) |sent|
                        std.mem.sliceTo(value, sent)
                    else
                        value;
                    return dumpString(tree, slice);
                }
                return dumpSlice(tree, ptr.child, value);
            },
            .many, .c => {
                if (ptr.child == u8) {
                    if (ptr.sentinel()) |sent| {
                        const slice = std.mem.sliceTo(value, sent);
                        return dumpString(tree, slice);
                    }
                }
                return tree.format("*{s}@{x}", .{ @typeName(ptr.child), @intFromPtr(value) });
            },
            .one => {
                switch (@typeInfo(ptr.child)) {
                    .array => |arr| {
                        if (arr.child == u8) {
                            const data = if (arr.sentinel()) |sent|
                                std.mem.sliceTo(@as([]const u8, value.*[0..]), sent)
                            else
                                value.*[0..];
                            return dumpString(tree, data);
                        }
                    },
                    else => {},
                }
                return tree.format("*{s}@{x}", .{ @typeName(ptr.child), @intFromPtr(value) });
            },
        },
        else => {
            return tree.format("<{s}>", .{@typeName(T)});
        },
    }
}

fn dumpStruct(
    tree: *Tree,
    comptime info: std.builtin.Type.Struct,
    value: anytype,
) !Node {
    if (info.fields.len == 0) {
        return tree.text(".{}");
    }

    var items = std.ArrayList(Node){};
    defer items.deinit(tree.bank);

    inline for (info.fields) |field| {
        const field_value = @field(value, field.name);
        const value_node = try dumpTyped(tree, field.type, field_value);
        const head = try tree.format(".{s} = ", .{field.name});
        try items.append(tree.bank, try tree.plus(head, value_node));
    }

    return container(tree, items.items);
}

fn dumpTuple(
    tree: *Tree,
    comptime info: std.builtin.Type.Struct,
    value: anytype,
) !Node {
    if (info.fields.len == 0) {
        return tree.text(".{}");
    }

    var items = std.ArrayList(Node){};
    defer items.deinit(tree.bank);

    inline for (info.fields) |field| {
        const elem = @field(value, field.name);
        try items.append(tree.bank, try dumpTyped(tree, field.type, elem));
    }

    return container(tree, items.items);
}

fn dumpArray(tree: *Tree, value: anytype) !Node {
    if (value.len == 0) {
        return tree.text(".{}");
    }

    var items = std.ArrayList(Node){};
    defer items.deinit(tree.bank);

    for (value) |elem| {
        try items.append(tree.bank, try dumpTyped(tree, @TypeOf(elem), elem));
    }

    return container(tree, items.items);
}

fn dumpSlice(tree: *Tree, comptime Child: type, value: []const Child) !Node {
    if (value.len == 0) {
        return tree.text(".{}");
    }

    var items = std.ArrayList(Node){};
    defer items.deinit(tree.bank);

    for (value) |elem| {
        try items.append(tree.bank, try dumpTyped(tree, Child, elem));
    }

    return container(tree, items.items);
}

fn dumpTaggedUnion(
    tree: *Tree,
    comptime info: std.builtin.Type.Union,
    value: anytype,
) !Node {
    const tag = std.meta.activeTag(value);
    const tag_name = @tagName(tag);

    inline for (info.fields) |field| {
        if (std.mem.eql(u8, field.name, tag_name)) {
            if (field.type == void) {
                const item = try tree.format(".{s}", .{tag_name});
                return container(tree, &.{item});
            } else {
                const head = try tree.format(".{s} = ", .{tag_name});
                const payload = @field(value, field.name);
                const tail = try dumpTyped(tree, field.type, payload);
                const item = try tree.plus(head, tail);
                return container(tree, &.{item});
            }
        }
    }

    return tree.format("<{s}>", .{@typeName(@TypeOf(value))});
}

fn dumpString(tree: *Tree, slice: []const u8) !Node {
    var buf = std.ArrayList(u8){};
    defer buf.deinit(tree.bank);

    try buf.append(tree.bank, '"');
    for (slice) |c| {
        switch (c) {
            '"' => try buf.appendSlice(tree.bank, "\\\""),
            '\\' => try buf.appendSlice(tree.bank, "\\\\"),
            '\n' => try buf.appendSlice(tree.bank, "\\n"),
            '\r' => try buf.appendSlice(tree.bank, "\\r"),
            '\t' => try buf.appendSlice(tree.bank, "\\t"),
            else => {
                if (c < 32 or c == 127) {
                    var tmp: [4]u8 = undefined;
                    const written = try std.fmt.bufPrint(&tmp, "\\x{X:0>2}", .{c});
                    try buf.appendSlice(tree.bank, written);
                } else {
                    try buf.append(tree.bank, c);
                }
            },
        }
    }
    try buf.append(tree.bank, '"');

    const owned = try buf.toOwnedSliceSentinel(tree.bank, 0);
    defer tree.bank.free(owned);

    return tree.text(owned);
}

fn container(tree: *Tree, items: []const Node) !Node {
    if (items.len == 0) {
        return tree.text(".{}");
    }

    var with_commas = std.ArrayList(Node){};
    defer with_commas.deinit(tree.bank);

    const comma = try tree.text(",");
    for (items) |item| {
        const line = try tree.plus(item, comma);
        try with_commas.append(tree.bank, line);
    }

    const block_body =
        try tree.pile(with_commas.items);

    const indented_body = block_body;

    const block_doc =
        try tree.pile(
            &.{
                try tree.nest(
                    2,
                    try tree.pile(&.{
                        try tree.text(".{"),
                        indented_body,
                    }),
                ),
                try tree.text("}"),
            },
        );

    return tree.fork(
        try tree.flat(block_doc),
        block_doc,
    );
}

const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;

test "dump struct inline by default" {
    var tree = Tree.init(std.testing.allocator);
    defer tree.deinit();

    const Data = struct { x: u8, y: u8 };
    const doc = try dump(&tree, Data{ .x = 1, .y = 2 });

    var path = try tree.best(std.testing.allocator, pretty.F1.init(80), doc, null);
    defer path.deinit(std.testing.allocator);

    var buffer: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(buffer[0..]);
    try tree.renderWithPath(&writer, doc, &path);
    const rendered = writer.buffered();
    try expectEqualStrings(".{ .x = 1, .y = 2 }", rendered);
}

test "dump chooses multiline layout when narrow" {
    var tree = Tree.init(std.testing.allocator);
    defer tree.deinit();

    const Data = struct {
        name: []const u8,
        description: []const u8,
    };

    const doc = try dump(
        &tree,
        Data{
            .name = "pretty",
            .description = "a printer that really wants room to breathe",
        },
    );

    var path = try tree.best(std.testing.allocator, pretty.F1.init(18), doc, null);
    defer path.deinit(std.testing.allocator);

    var buffer: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(buffer[0..]);
    try tree.renderWithPath(&writer, doc, &path);
    const rendered = writer.buffered();

    try expect(std.mem.indexOf(u8, rendered, "\n") != null);
}

test "dump escapes strings" {
    var tree = Tree.init(std.testing.allocator);
    defer tree.deinit();

    const doc = try dump(&tree, "quote \" and newline\n");

    var buffer: [64]u8 = undefined;
    const rendered = try tree.render(buffer[0..], doc);

    try expectEqualStrings("\"quote \\\" and newline\\n\"", rendered);
}
