// Pretty printer for Zig values using StyledDocPrinter's optimal layout algorithm
// Usage: wrap in ArenaAllocator since it generates many intermediate docs

const std = @import("std");
const ColorPrinter = @import("ColorPrinter.zig");
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;

pub const Style = enum {
    normal,
    number,
    string,
    keyword,
    field_name,
    type_name,
    punctuation,
};

const P = @import("StyledDocPrinter.zig");
const Doc = P.Doc;

pub const Options = struct {
    max_width: u16 = 80,
    max_depth: u32 = 10,
};

pub fn pretty(
    comptime T: type,
    value: T,
    alloc: Allocator,
    opts: Options,
) !Doc {
    return prettyDepth(false, T, value, alloc, opts, 0);
}

pub fn prettyComptime(
    comptime T: type,
    comptime value: T,
    alloc: Allocator,
    opts: Options,
) !Doc {
    return prettyDepthComptime(T, value, alloc, opts, 0);
}

fn prettyDepth(
    comptime is_comptime: bool,
    comptime T: type,
    value: T,
    alloc: Allocator,
    opts: Options,
    depth: u32,
) !Doc {
    if (depth >= opts.max_depth) {
        return P.text("...", Style.normal, alloc);
    }

    switch (@typeInfo(T)) {
        .int, .comptime_int => {
            const str = try std.fmt.allocPrint(alloc, "{d}", .{value});
            return P.text(str, Style.number, alloc);
        },
        .float, .comptime_float => {
            const str = try std.fmt.allocPrint(alloc, "{d}", .{value});
            return P.text(str, Style.number, alloc);
        },
        .bool => {
            return P.text(if (value) "true" else "false", Style.keyword, alloc);
        },
        .void => {
            return P.text("void", Style.keyword, alloc);
        },
        .type => {
            return P.text(@typeName(value), Style.type_name, alloc);
        },
        .@"enum" => {
            const str = try std.fmt.allocPrint(alloc, ".{s}", .{@tagName(value)});
            return P.text(str, Style.keyword, alloc);
        },
        .enum_literal => {
            const str = try std.fmt.allocPrint(alloc, ".{s}", .{@tagName(value)});
            return P.text(str, Style.keyword, alloc);
        },
        .null => {
            return P.text("null", Style.keyword, alloc);
        },
        .optional => {
            if (value) |payload| {
                return prettyDepth(is_comptime, @TypeOf(payload), payload, alloc, opts, depth);
            } else {
                return P.text("null", Style.keyword, alloc);
            }
        },
        .error_set => {
            const str = try std.fmt.allocPrint(alloc, "error.{s}", .{@errorName(value)});
            return P.text(str, Style.keyword, alloc);
        },
        .error_union => {
            if (value) |payload| {
                return prettyDepth(is_comptime, @TypeOf(payload), payload, alloc, opts, depth);
            } else |err| {
                return prettyDepth(is_comptime, @TypeOf(err), err, alloc, opts, depth);
            }
        },
        .@"struct" => |info| {
            if (info.is_tuple) {
                return prettyTuple(is_comptime, T, value, alloc, opts, depth, info);
            } else {
                return prettyStruct(is_comptime, T, value, alloc, opts, depth, info);
            }
        },
        .@"union" => |info| {
            if (info.tag_type) |_| {
                const tag = std.meta.activeTag(value);
                const tag_name = @tagName(tag);
                const tag_str = try std.fmt.allocPrint(alloc, ".{{ .{s} = ", .{tag_name});
                const open = try P.text(tag_str, Style.field_name, alloc);
                const close = try P.text(" }", Style.punctuation, alloc);

                const field_doc = switch (value) {
                    inline else => |field_value| try prettyDepth(
                        is_comptime,
                        @TypeOf(field_value),
                        field_value,
                        alloc,
                        opts,
                        depth + 1,
                    ),
                };

                const tmp = try P.hcat(opts.max_width, open, field_doc, alloc);
                return P.hcat(opts.max_width, tmp, close, alloc);
            } else switch (info.layout) {
                .auto => {
                    return P.text(".{ ... }", Style.punctuation, alloc);
                },
                .@"extern", .@"packed" => {
                    if (info.fields.len == 0) {
                        return P.text(".{}", Style.punctuation, alloc);
                    }

                    var fields = std.ArrayList(Doc){};
                    inline for (info.fields) |field| {
                        const field_name = try std.fmt.allocPrint(alloc, ".{s} = ", .{field.name});
                        const name_box = try P.Box.text(field_name, Style.field_name, alloc);
                        const value_doc = try prettyDepth(is_comptime, field.type, @field(value, field.name), alloc, opts, depth + 1);

                        var field_boxes = std.ArrayList(P.Box){};
                        for (value_doc) |value_box| {
                            const field_box = try name_box.hcat(value_box, alloc);
                            try field_boxes.append(alloc, field_box);
                        }
                        try fields.append(alloc, try field_boxes.toOwnedSlice(alloc));
                    }

                    const open_box = try P.Box.text(".{ ", Style.punctuation, alloc);
                    const close_box = try P.Box.text(" }", Style.punctuation, alloc);
                    const joined = try joinWithCommas(opts.max_width, fields.items, alloc);

                    var result = std.ArrayList(P.Box){};
                    for (joined) |joined_box| {
                        var tmp1 = try open_box.hcat(joined_box, alloc);
                        const tmp2 = try tmp1.hcat(close_box, alloc);
                        try result.append(alloc, tmp2);
                    }

                    return result.toOwnedSlice(alloc);
                },
            }
        },
        .array => |info| {
            if (info.child == u8) {
                return prettyString(value[0..], alloc);
            }
            return prettyArray(is_comptime, value, alloc, opts, depth);
        },
        .pointer => |ptr_info| switch (ptr_info.size) {
            .slice => {
                if (ptr_info.child == u8) {
                    return prettyString(value, alloc);
                }
                return prettySlice(is_comptime, T, value, alloc, opts, depth);
            },
            .one => switch (@typeInfo(ptr_info.child)) {
                .array => return prettyDepth(is_comptime, @TypeOf(value.*), value.*, alloc, opts, depth),
                .@"struct", .@"union", .@"enum" => return prettyDepth(is_comptime, @TypeOf(value.*), value.*, alloc, opts, depth),
                else => {
                    const str = try std.fmt.allocPrint(alloc, "*{s}@{x}", .{ @typeName(ptr_info.child), @intFromPtr(value) });
                    return P.text(str, Style.normal, alloc);
                },
            },
            else => {
                const str = try std.fmt.allocPrint(alloc, "@{x}", .{@intFromPtr(value)});
                return P.text(str, Style.normal, alloc);
            },
        },
        else => {
            const str = try std.fmt.allocPrint(alloc, "<{s}>", .{@typeName(T)});
            return P.text(str, Style.type_name, alloc);
        },
    }
}

fn prettyString(value: []const u8, alloc: Allocator) !Doc {
    var buf = std.ArrayList(u8){};
    try buf.append(alloc, '"');
    for (value) |c| {
        switch (c) {
            '"' => try buf.appendSlice(alloc, "\\\""),
            '\\' => try buf.appendSlice(alloc, "\\\\"),
            '\n' => try buf.appendSlice(alloc, "\\n"),
            '\r' => try buf.appendSlice(alloc, "\\r"),
            '\t' => try buf.appendSlice(alloc, "\\t"),
            0 => break,
            else => try buf.append(alloc, c),
        }
    }
    try buf.append(alloc, '"');
    return P.text(try buf.toOwnedSlice(alloc), Style.string, alloc);
}

fn joinWithCommas(max_width: u16, docs: []const Doc, alloc: Allocator) !Doc {
    _ = max_width;
    if (docs.len == 0) return P.text("", Style.normal, alloc);
    if (docs.len == 1) return docs[0];

    const comma_doc = try P.text(", ", Style.punctuation, alloc);

    // Build horizontal: elem1, elem2, elem3
    var h = docs[0];
    for (docs[1..]) |doc| {
        var tmp = std.ArrayList(P.Box){};
        for (h) |h_box| {
            for (comma_doc) |comma_box| {
                for (doc) |doc_box| {
                    var step1 = try h_box.hcat(comma_box, alloc);
                    const step2 = try step1.hcat(doc_box, alloc);
                    try tmp.append(alloc, step2);
                }
            }
        }
        h = try tmp.toOwnedSlice(alloc);
    }

    // Build vertical: elem1,\nelem2,\nelem3
    const comma_only = try P.text(",", Style.punctuation, alloc);
    var v = docs[0];
    for (docs[1..]) |doc| {
        var tmp = std.ArrayList(P.Box){};
        for (v) |v_box| {
            for (comma_only) |comma_box| {
                for (doc) |doc_box| {
                    var with_comma = try v_box.hcat(comma_box, alloc);
                    const combined = try with_comma.vcat(doc_box, alloc);
                    try tmp.append(alloc, combined);
                }
            }
        }
        v = try tmp.toOwnedSlice(alloc);
    }

    // Combine candidates
    var all = std.ArrayList(P.Box){};
    try all.appendSlice(alloc, h);
    try all.appendSlice(alloc, v);

    return P.pareto(all.items, alloc);
}

fn prettyStruct(
    comptime is_comptime: bool,
    comptime T: type,
    value: T,
    alloc: Allocator,
    opts: Options,
    depth: u32,
    comptime info: std.builtin.Type.Struct,
) !Doc {
    if (info.fields.len == 0) {
        return P.text(".{}", Style.punctuation, alloc);
    }

    var fields = std.ArrayList(Doc){};

    inline for (info.fields) |field| {
        const field_name = try std.fmt.allocPrint(alloc, ".{s} = ", .{field.name});
        const name_box = try P.Box.text(field_name, @intFromEnum(Style.field_name), alloc);
        const value_doc = try prettyDepth(is_comptime, field.type, @field(value, field.name), alloc, opts, depth + 1);

        var field_boxes = std.ArrayList(P.Box){};
        for (value_doc) |value_box| {
            const field_box = try name_box.hcat(value_box, alloc);
            try field_boxes.append(alloc, field_box);
        }
        try fields.append(alloc, try field_boxes.toOwnedSlice(alloc));
    }

    const open_box = try P.Box.text(".{ ", @intFromEnum(Style.punctuation), alloc);
    const close_box = try P.Box.text(" }", @intFromEnum(Style.punctuation), alloc);
    const joined = try joinWithCommas(opts.max_width, fields.items, alloc);

    var result = std.ArrayList(P.Box){};
    for (joined) |joined_box| {
        var tmp1 = try open_box.hcat(joined_box, alloc);
        const tmp2 = try tmp1.hcat(close_box, alloc);
        try result.append(alloc, tmp2);
    }

    return result.toOwnedSlice(alloc);
}

fn prettyTuple(
    comptime is_comptime: bool,
    comptime T: type,
    value: T,
    alloc: Allocator,
    opts: Options,
    depth: u32,
    comptime info: std.builtin.Type.Struct,
) !Doc {
    if (info.fields.len == 0) {
        return P.text(".{}", .punctuation, alloc);
    }

    var elements = std.ArrayList(Doc){};

    inline for (info.fields) |field| {
        const elem_doc = try prettyDepth(is_comptime, field.type, @field(value, field.name), alloc, opts, depth + 1);
        try elements.append(alloc, elem_doc);
    }

    const open_box = try P.Box.text(".{ ", .punctuation, alloc);
    const close_box = try P.Box.text(" }", .punctuation, alloc);
    const joined = try joinWithCommas(opts.max_width, elements.items, alloc);

    var result = std.ArrayList(P.Box){};
    for (joined) |joined_box| {
        var tmp1 = try open_box.hcat(joined_box, alloc);
        const tmp2 = try tmp1.hcat(close_box, alloc);
        try result.append(alloc, tmp2);
    }

    return result.toOwnedSlice(alloc);
}

fn prettyArray(
    comptime is_comptime: bool,
    value: anytype,
    alloc: Allocator,
    opts: Options,
    depth: u32,
) !Doc {
    if (value.len == 0) {
        return P.text(".{}", .punctuation, alloc);
    }

    var elements = std.ArrayList(Doc){};

    if (is_comptime) {
        inline for (value) |elem| {
            const elem_doc = try prettyDepth(is_comptime, @TypeOf(elem), elem, alloc, opts, depth + 1);
            try elements.append(alloc, elem_doc);
        }
    } else {
        for (value) |elem| {
            const elem_doc = try prettyDepth(is_comptime, @TypeOf(elem), elem, alloc, opts, depth + 1);
            try elements.append(alloc, elem_doc);
        }
    }

    const open_box = try P.Box.text(".{ ", @intFromEnum(Style.punctuation), alloc);
    const close_box = try P.Box.text(" }", @intFromEnum(Style.punctuation), alloc);
    const joined = try joinWithCommas(opts.max_width, elements.items, alloc);

    var result = std.ArrayList(P.Box){};
    for (joined) |joined_box| {
        var tmp1 = try open_box.hcat(joined_box, alloc);
        const tmp2 = try tmp1.hcat(close_box, alloc);
        try result.append(alloc, tmp2);
    }

    return result.toOwnedSlice(alloc);
}

fn prettySlice(
    comptime is_comptime: bool,
    comptime T: type,
    value: T,
    alloc: Allocator,
    opts: Options,
    depth: u32,
) !Doc {
    if (value.len == 0) {
        return P.text(".{}", Style.punctuation, alloc);
    }

    const child = @typeInfo(T).pointer.child;

    var elements = std.ArrayList(Doc){};

    if (is_comptime) {
        inline for (value) |elem| {
            const elem_doc = try prettyDepth(is_comptime, child, elem, alloc, opts, depth + 1);
            try elements.append(alloc, elem_doc);
        }
    } else {
        for (value) |elem| {
            const elem_doc = try prettyDepth(is_comptime, child, elem, alloc, opts, depth + 1);
            try elements.append(alloc, elem_doc);
        }
    }

    const open_box = try P.Box.text(".{ ", @intFromEnum(Style.punctuation), alloc);
    const close_box = try P.Box.text(" }", @intFromEnum(Style.punctuation), alloc);
    const joined = try joinWithCommas(opts.max_width, elements.items, alloc);

    var result = std.ArrayList(P.Box){};
    for (joined) |joined_box| {
        var tmp1 = try open_box.hcat(joined_box, alloc);
        const tmp2 = try tmp1.hcat(close_box, alloc);
        try result.append(alloc, tmp2);
    }

    return result.toOwnedSlice(alloc);
}

/// Print value to string (no styling)
pub fn print(
    comptime T: type,
    value: T,
    alloc: Allocator,
    opts: Options,
) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const tmp = arena.allocator();

    const doc = try pretty(T, value, tmp, opts);
    const result = (try P.renderPlain(doc, opts.max_width, tmp)) orelse "";
    return alloc.dupe(u8, result);
}

/// Print value with styling using ColorPrinter
pub fn printStyled(
    comptime T: type,
    value: T,
    alloc: Allocator,
    writer: *Writer,
    printer: *ColorPrinter.ColorPrinter(Style),
    opts: Options,
) !void {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const tmp = arena.allocator();

    const doc = try pretty(T, value, tmp, opts);
    const segments = (try P.renderSegments(doc, opts.max_width, tmp)) orelse return;

    for (segments) |seg| {
        try writer.splatByteAll(' ', seg.tab);
        if (printer.theme.get(@enumFromInt(seg.ink))) |_| {
            try printer.print(@enumFromInt(seg.ink), "{s}", .{seg.txt});
        } else {
            try writer.writeAll(seg.txt);
        }
    }
}

// Comptime-only version for values known at comptime (like @typeInfo results)
fn prettyDepthComptime(
    comptime T: type,
    comptime value: T,
    alloc: Allocator,
    opts: Options,
    depth: u32,
) !Doc {
    if (depth >= opts.max_depth) {
        return P.text("...", Style.normal, alloc);
    }

    switch (@typeInfo(T)) {
        .int, .comptime_int => {
            const str = try std.fmt.allocPrint(alloc, "{d}", .{value});
            return P.text(str, Style.number, alloc);
        },
        .float, .comptime_float => {
            const str = try std.fmt.allocPrint(alloc, "{d}", .{value});
            return P.text(str, Style.number, alloc);
        },
        .bool => {
            return P.text(if (value) "true" else "false", Style.keyword, alloc);
        },
        .void => {
            return P.text("void", Style.keyword, alloc);
        },
        .type => {
            return P.text(@typeName(value), Style.type_name, alloc);
        },
        .@"enum" => {
            const str = try std.fmt.allocPrint(alloc, ".{s}", .{@tagName(value)});
            return P.text(str, Style.keyword, alloc);
        },
        .enum_literal => {
            const str = try std.fmt.allocPrint(alloc, ".{s}", .{@tagName(value)});
            return P.text(str, Style.keyword, alloc);
        },
        .null => {
            return P.text("null", Style.keyword, alloc);
        },
        .optional => {
            if (value) |payload| {
                return prettyDepthComptime(@TypeOf(payload), payload, alloc, opts, depth);
            } else {
                return P.text("null", Style.keyword, alloc);
            }
        },
        .@"struct" => |info| {
            if (info.is_tuple) {
                return prettyTupleComptime(T, value, alloc, opts, depth, info);
            } else {
                return prettyStructComptime(T, value, alloc, opts, depth, info);
            }
        },
        .@"union" => |info| {
            if (info.tag_type) |_| {
                const tag = std.meta.activeTag(value);
                const tag_name = @tagName(tag);
                const tag_str = try std.fmt.allocPrint(alloc, ".{{ .{s} = ", .{tag_name});
                const open = try P.text(tag_str, Style.field_name, alloc);
                const close = try P.text(" }", Style.punctuation, alloc);

                const field_doc = switch (value) {
                    inline else => |field_value| try prettyDepthComptime(
                        @TypeOf(field_value),
                        field_value,
                        alloc,
                        opts,
                        depth + 1,
                    ),
                };

                const tmp = try P.hcat(opts.max_width, open, field_doc, alloc);
                return P.hcat(opts.max_width, tmp, close, alloc);
            } else {
                return P.text(".{ ... }", Style.punctuation, alloc);
            }
        },
        .array => |info| {
            if (info.child == u8) {
                return prettyString(value[0..], alloc);
            }
            return prettyArrayComptime(value, alloc, opts, depth);
        },
        .pointer => |ptr_info| switch (ptr_info.size) {
            .slice => {
                if (ptr_info.child == u8) {
                    return prettyString(value, alloc);
                }
                return prettySliceComptime(T, value, alloc, opts, depth);
            },
            .one => switch (@typeInfo(ptr_info.child)) {
                .array => return prettyDepthComptime(@TypeOf(value.*), value.*, alloc, opts, depth),
                .@"struct", .@"union", .@"enum" => return prettyDepthComptime(@TypeOf(value.*), value.*, alloc, opts, depth),
                else => {
                    const str = try std.fmt.allocPrint(alloc, "*{s}@{x}", .{ @typeName(ptr_info.child), @intFromPtr(value) });
                    return P.text(str, Style.normal, alloc);
                },
            },
            else => {
                const str = try std.fmt.allocPrint(alloc, "@{x}", .{@intFromPtr(value)});
                return P.text(str, Style.normal, alloc);
            },
        },
        else => {
            const str = try std.fmt.allocPrint(alloc, "<{s}>", .{@typeName(T)});
            return P.text(str, Style.type_name, alloc);
        },
    }
}

fn prettyStructComptime(
    comptime T: type,
    comptime value: T,
    alloc: Allocator,
    opts: Options,
    depth: u32,
    comptime info: std.builtin.Type.Struct,
) !Doc {
    if (info.fields.len == 0) {
        return P.text(".{}", Style.punctuation, alloc);
    }

    var fields = std.ArrayList(Doc){};

    inline for (info.fields) |field| {
        const field_name = try std.fmt.allocPrint(alloc, ".{s} = ", .{field.name});
        const name_box = try P.Box.text(field_name, @intFromEnum(Style.field_name), alloc);
        const value_doc = try prettyDepthComptime(field.type, @field(value, field.name), alloc, opts, depth + 1);

        var field_boxes = std.ArrayList(P.Box){};
        for (value_doc) |value_box| {
            const field_box = try name_box.hcat(value_box, alloc);
            try field_boxes.append(alloc, field_box);
        }
        try fields.append(alloc, try field_boxes.toOwnedSlice(alloc));
    }

    const open_box = try P.Box.text(".{ ", @intFromEnum(Style.punctuation), alloc);
    const close_box = try P.Box.text(" }", @intFromEnum(Style.punctuation), alloc);
    const joined = try joinWithCommas(opts.max_width, fields.items, alloc);

    var result = std.ArrayList(P.Box){};
    for (joined) |joined_box| {
        var tmp1 = try open_box.hcat(joined_box, alloc);
        const tmp2 = try tmp1.hcat(close_box, alloc);
        try result.append(alloc, tmp2);
    }

    return result.toOwnedSlice(alloc);
}

fn prettyTupleComptime(
    comptime T: type,
    comptime value: T,
    alloc: Allocator,
    opts: Options,
    depth: u32,
    comptime info: std.builtin.Type.Struct,
) !Doc {
    if (info.fields.len == 0) {
        return P.text(".{}", .punctuation, alloc);
    }

    var elements = std.ArrayList(Doc){};

    inline for (info.fields) |field| {
        const elem_doc = try prettyDepthComptime(field.type, @field(value, field.name), alloc, opts, depth + 1);
        try elements.append(alloc, elem_doc);
    }

    const open_box = try P.Box.text(".{ ", .punctuation, alloc);
    const close_box = try P.Box.text(" }", .punctuation, alloc);
    const joined = try joinWithCommas(opts.max_width, elements.items, alloc);

    var result = std.ArrayList(P.Box){};
    for (joined) |joined_box| {
        var tmp1 = try open_box.hcat(joined_box, alloc);
        const tmp2 = try tmp1.hcat(close_box, alloc);
        try result.append(alloc, tmp2);
    }

    return result.toOwnedSlice(alloc);
}

fn prettyArrayComptime(
    comptime value: anytype,
    alloc: Allocator,
    opts: Options,
    depth: u32,
) !Doc {
    if (value.len == 0) {
        return P.text(".{}", .punctuation, alloc);
    }

    var elements = std.ArrayList(Doc){};

    inline for (value) |elem| {
        const elem_doc = try prettyDepthComptime(@TypeOf(elem), elem, alloc, opts, depth + 1);
        try elements.append(alloc, elem_doc);
    }

    const open_box = try P.Box.text(".{ ", .punctuation, alloc);
    const close_box = try P.Box.text(" }", .punctuation, alloc);
    const joined = try joinWithCommas(opts.max_width, elements.items, alloc);

    var result = std.ArrayList(P.Box){};
    for (joined) |joined_box| {
        var tmp1 = try open_box.hcat(joined_box, alloc);
        const tmp2 = try tmp1.hcat(close_box, alloc);
        try result.append(alloc, tmp2);
    }

    return result.toOwnedSlice(alloc);
}

fn prettySliceComptime(
    comptime T: type,
    comptime value: T,
    alloc: Allocator,
    opts: Options,
    depth: u32,
) !Doc {
    if (value.len == 0) {
        return P.text(".{}", Style.punctuation, alloc);
    }

    const child = @typeInfo(T).pointer.child;

    var elements = std.ArrayList(Doc){};

    inline for (value) |elem| {
        const elem_doc = try prettyDepthComptime(child, elem, alloc, opts, depth + 1);
        try elements.append(alloc, elem_doc);
    }

    const open_box = try P.Box.text(".{ ", @intFromEnum(Style.punctuation), alloc);
    const close_box = try P.Box.text(" }", @intFromEnum(Style.punctuation), alloc);
    const joined = try joinWithCommas(opts.max_width, elements.items, alloc);

    var result = std.ArrayList(P.Box){};
    for (joined) |joined_box| {
        var tmp1 = try open_box.hcat(joined_box, alloc);
        const tmp2 = try tmp1.hcat(close_box, alloc);
        try result.append(alloc, tmp2);
    }

    return result.toOwnedSlice(alloc);
}

test "pretty print simple struct" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    const p = Point{ .x = 10, .y = 20 };
    const result = try print(Point, p, std.testing.allocator, .{ .max_width = 80 });
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings(".{ .x = 10, .y = 20 }", result);
}

test "pretty print with narrow width" {
    const data = .{
        .very_long_field_name_one = 123456,
        .very_long_field_name_two = 789012,
        .very_long_field_name_three = 345678,
    };

    const result = try print(@TypeOf(data), data, std.testing.allocator, .{ .max_width = 30 });
    defer std.testing.allocator.free(result);

    // At narrow width, should use vertical layout (multiple lines)
    try std.testing.expect(std.mem.indexOf(u8, result, "\n") != null);
}
