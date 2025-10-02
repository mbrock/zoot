// Optimal pretty printing based on "A Pretty But Not Greedy Printer"
// by Jean-Philippe Bernardy (JFP 2017)
//
// Core idea: maintain a set of candidate layouts (Pareto frontier)
// filtered by dominance relation on (lines, max_width, final_width)

const std = @import("std");
const Allocator = std.mem.Allocator;

/// A layout candidate with metrics
pub const Box = struct {
    /// Text lines (length = lines + 1, last line is "final")
    txt: std.ArrayList(std.ArrayList(u8)),
    /// Number of complete lines (not counting final)
    lines: u16,
    /// Length of final incomplete line
    final: u16,
    /// Maximum line length across all lines
    max: u16,

    pub fn text(bytes: []const u8, alloc: Allocator) !Box {
        var line = std.ArrayList(u8){};
        try line.appendSlice(alloc, bytes);

        var txt = std.ArrayList(std.ArrayList(u8)){};
        try txt.append(alloc, line);

        return .{
            .txt = txt,
            .lines = 0,
            .final = @intCast(bytes.len),
            .max = @intCast(bytes.len),
        };
    }

    pub fn deinit(self: *Box, alloc: Allocator) void {
        for (self.txt.items) |*line| line.deinit(alloc);
        self.txt.deinit(alloc);
    }

    /// Add indentation to all lines
    pub fn indent(self: Box, n: u16, alloc: Allocator) !Box {
        var result = Box{
            .txt = std.ArrayList(std.ArrayList(u8)){},
            .lines = self.lines,
            .final = self.final + n,
            .max = self.max + n,
        };

        for (self.txt.items) |line| {
            var new_line = std.ArrayList(u8){};
            try new_line.appendNTimes(alloc, ' ', n);
            try new_line.appendSlice(alloc, line.items);
            try result.txt.append(alloc, new_line);
        }

        return result;
    }

    /// Insert a line break at the end
    pub fn flush(self: Box, alloc: Allocator) !Box {
        var result = Box{
            .txt = std.ArrayList(std.ArrayList(u8)){},
            .lines = self.lines + 1,
            .max = self.max,
            .final = 0,
        };

        try result.txt.appendSlice(alloc, self.txt.items);
        try result.txt.append(alloc, std.ArrayList(u8){});

        return result;
    }

    /// Horizontal concatenation
    pub fn hcat(a: Box, b: Box, alloc: Allocator) !Box {
        var result = Box{
            .txt = std.ArrayList(std.ArrayList(u8)){},
            .lines = a.lines + b.lines,
            .final = a.final + b.final,
            .max = @max(a.max, b.max + a.final),
        };

        // Copy a's complete lines
        for (a.txt.items[0..a.lines]) |line| {
            var new_line = std.ArrayList(u8){};
            try new_line.appendSlice(alloc, line.items);
            try result.txt.append(alloc, new_line);
        }

        // Merge a's final with b's first
        const last_a = a.txt.items[a.lines];
        const first_b = b.txt.items[0];

        var merged = std.ArrayList(u8){};
        try merged.appendSlice(alloc, last_a.items);
        try merged.appendSlice(alloc, first_b.items);
        try result.txt.append(alloc, merged);

        // Copy b's remaining lines, indented by a's final width
        for (b.txt.items[1 .. b.lines + 1]) |line| {
            var new_line = std.ArrayList(u8){};
            try new_line.appendNTimes(alloc, ' ', a.final);
            try new_line.appendSlice(alloc, line.items);
            try result.txt.append(alloc, new_line);
        }

        return result;
    }

    /// Vertical concatenation (flush a, then hcat)
    pub fn vcat(a: Box, b: Box, alloc: Allocator) !Box {
        const flushed = try a.flush(alloc);
        return try flushed.hcat(b, alloc);
    }

    /// Check if this box dominates another (better or equal on all metrics)
    pub fn beats(a: Box, b: Box) bool {
        return a.lines <= b.lines and a.max <= b.max and a.final <= b.final;
    }

    /// Render to string
    pub fn render(self: Box, alloc: Allocator) ![]const u8 {
        var result = std.ArrayList(u8){};
        for (self.txt.items, 0..) |line, i| {
            if (i > 0) try result.append(alloc, '\n');
            try result.appendSlice(alloc, line.items);
        }
        return result.toOwnedSlice(alloc);
    }
};

/// A document is a set of layout candidates
pub const Doc = []const Box;

/// Pareto frontier: keep only non-dominated boxes
pub fn pareto(boxes: []const Box, alloc: Allocator) !Doc {
    var result = std.ArrayList(Box){};

    boxloop: for (boxes) |x| {
        // Skip if any existing box beats x
        for (result.items) |a| {
            if (a.beats(x)) continue :boxloop;
        }

        // Remove boxes that x beats
        var i: usize = 0;
        while (i < result.items.len) {
            if (x.beats(result.items[i])) {
                var beaten = result.orderedRemove(i);
                beaten.deinit(alloc);
            } else {
                i += 1;
            }
        }

        try result.append(alloc, x);
    }

    return result.toOwnedSlice(alloc);
}

/// Document builder helpers
pub fn text(bytes: []const u8, alloc: Allocator) !Doc {
    const box = try Box.text(bytes, alloc);
    const result = try alloc.alloc(Box, 1);
    result[0] = box;
    return result;
}

/// Concatenate two docs horizontally
pub fn hcat(max_width: u16, a: Doc, b: Doc, alloc: Allocator) !Doc {
    var candidates = std.ArrayList(Box){};

    for (a) |x| {
        for (b) |y| {
            const xy = try x.hcat(y, alloc);
            if (xy.max <= max_width) {
                try candidates.append(alloc, xy);
            } else {
                var mutable = xy;
                mutable.deinit(alloc);
            }
        }
    }

    return pareto(candidates.items, alloc);
}

/// Flush all boxes in a doc
pub fn flush(a: Doc, alloc: Allocator) !Doc {
    var result = std.ArrayList(Box){};
    for (a) |x| {
        try result.append(alloc, try x.flush(alloc));
    }
    return result.toOwnedSlice(alloc);
}

/// Concatenate two docs vertically
pub fn vcat(max_width: u16, a: Doc, b: Doc, alloc: Allocator) !Doc {
    return hcat(max_width, try flush(a, alloc), b, alloc);
}

/// Choice: try horizontal, fallback to vertical
pub fn cat(max_width: u16, a: Doc, b: Doc, alloc: Allocator) !Doc {
    const h = try hcat(max_width, a, b, alloc);
    const v = try vcat(max_width, a, b, alloc);

    var candidates = std.ArrayList(Box){};
    try candidates.appendSlice(alloc, h);
    try candidates.appendSlice(alloc, v);

    return pareto(candidates.items, alloc);
}

/// Join multiple docs with spaces
pub fn hsep(max_width: u16, docs: []const Doc, alloc: Allocator) !Doc {
    if (docs.len == 0) return text("", alloc);
    var result = docs[0];
    const space = try text(" ", alloc);
    for (docs[1..]) |doc| {
        const tmp = try hcat(max_width, result, space, alloc);
        result = try hcat(max_width, tmp, doc, alloc);
    }
    return result;
}

/// Join multiple docs (try horizontal with spaces, fallback to vertical)
pub fn join(max_width: u16, docs: []const Doc, alloc: Allocator) !Doc {
    if (docs.len == 0) return text("", alloc);

    const h = try hsep(max_width, docs, alloc);

    var result = docs[0];
    for (docs[1..]) |doc| {
        result = try vcat(max_width, result, doc, alloc);
    }

    var candidates = std.ArrayList(Box){};
    try candidates.appendSlice(alloc, h);
    try candidates.appendSlice(alloc, result);

    return pareto(candidates.items, alloc);
}

/// Select best layout (fewest lines)
fn selectBest(_: void, a: Box, b: Box) bool {
    return a.lines < b.lines;
}

/// Render document to string (picks best layout)
pub fn render(doc: Doc, alloc: Allocator) !?[]const u8 {
    if (std.sort.min(Box, doc, {}, selectBest)) |best| {
        return try best.render(alloc);
    }
    return null;
}

/// Free a document and all its boxes
pub fn deinit(doc: Doc, alloc: Allocator) void {
    for (doc) |*box| {
        var mutable = box.*;
        mutable.deinit(alloc);
    }
    alloc.free(doc);
}

test "box hcat" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const a1 = try Box.text("aaaaa", alloc);
    const a2 = try Box.text("aa", alloc);
    const a = try a1.vcat(a2, alloc);

    const b1 = try Box.text("bbbbb", alloc);
    const b2 = try Box.text("bbbbbbb", alloc);
    const b = try b1.vcat(b2, alloc);

    const ab = try a.hcat(b, alloc);
    const result = try ab.render(alloc);

    try std.testing.expectEqualStrings(
        "aaaaa\n" ++
            "aabbbbb\n" ++
            "  bbbbbbb",
        result,
    );
}

test "pareto" {
    const alloc = std.testing.allocator;

    var boxes = [_]Box{
        .{ .txt = undefined, .lines = 0, .final = 0, .max = 0 },
        .{ .txt = undefined, .lines = 1, .final = 0, .max = 0 },
    };

    const result = try pareto(&boxes, alloc);
    defer alloc.free(result);

    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expectEqual(@as(u16, 0), result[0].lines);
}

test "simple doc" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const hello = try text("hello", alloc);
    const world = try text("world", alloc);
    const doc = try cat(80, hello, world, alloc);
    const result = (try render(doc, alloc)).?;

    // Should prefer horizontal layout
    try std.testing.expectEqualStrings("helloworld", result);
}
