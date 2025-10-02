// Jean-Philippe Bernardy published the basis for this concept and
// algorithm in a 2017 paper called "A Pretty But Not Greedy Printer."
//
// He constructs a pretty printing system in the "algebraic"
// tradition.  This tradition goes back to an influential 1995 pretty
// printing paper by John Hughes.  Dozens of pretty printing libraries
// to this day are based on Philip Wadler's 2002 paper that improved
// Hughes's algebra by making it even more algebraic.
//
// These papers tend to use associative binary combinators defined on
// an abstract "document" family of types, defining A <> B as, for
// example, the document formed by horizontal concatenation of
// documents A and B, in turn composed of smaller subdocuments
// combined in various ways.  Like compositional DSLs designed to
// capture the formal essence of how to specify the formatting of
// source code.
//
// The algebraic tradition thinks carefully about meanings and
// interpretations of such algebraic languages, tries to formulate
// laws that help reason about those meanings and help guide
// implementation.  You get to see a variety of "implementations" of
// the same algebra, different ways of assigning meaning to the
// syntactic forms, often a sequence of increasingly concrete or
// efficient interpretations.
//
// The document algebra is abstract, an open family of `Doc` types for
// which you can define the <> operator, etc.  In Haskell the algebra
// is a type class with laws, often extending some truly abstract
// algebraic pattern, especially the good old monoid.  If the algebra
// is sufficiently meaningful and well-specified, you can more or less
// instantiate `Doc` as some concrete type, like "list of strings",
// and just fiddle with your operator definitions until they satisfy
// the laws, and derive a concrete implementation that's "correct by
// construction."  This is the pattern of Hughes, Wadler, and so on.
//
// Bernardy does it just like this, too, but with one principal
// difference: instead of correctness laws that guide an efficient &
// unambiguous implementation, where the concrete meaning of the
// combinators is locally well-defined, his algebra is flexible, so
// that A <> B can denote either a vertical or a horizontal layout,
// and the interpretation he wants to concretize efficiently is one
// where the final layout is not just correct but optimal in a global
// sense, or at least "not suboptimal."
//
// It's very similar to like how Knuth's TeX paragraph justification
// algorithm does a branching search in layout space to find a
// solution that adequately minimizes some measure of badness.
// Bernardy wants his pretty printing semantics to crown a dominant
// layout from a combinatorial set of layouts.  The measure of quality
// is quite clear: forbid exceeding a column limit (80 chars, say),
// and minimize line count.  If two candidates have the same line
// count, the narrower one wins.  Additional constraints are embedded
// in the combinators, like a choice operator that groups any number
// of documents such that they're either all in a row, or all stacked
// vertically.
//
// Sitting down and trying to implement that with a bunch of strings
// and arrays would be messy, inefficient, and confusing.  The
// algebraic approach leads Bernardy to an elegant construction based
// on interpreting documents not as concrete strings but as numeric
// measures.  Ignoring the contents, he maps each document to a
// triplet of integers: number of lines, widest line, and width of
// last line.  That's enough to characterize the document insofar as
// his layout algebra is concerned.  Formally the measurement
// interpretation is a homomorphism; all the algebra's operations are
// well-defined on integer triples in a "structure-preserving" way,
// such that, if m maps documents to measurements, then
//
//   m(A <> B) = m(A) <> m(B)
//
// for all documents A and B, and so on for all the layout
// combinators.
//
// Bernardy defines the document-as-measurement interpretation and
// proves that it's a structure-preserving homomorphism.  This is
// enough to straightforwardly do a combinatorial search for optimal
// layouts without doing any string manipulation, just simple integer
// arithmetic.  But the search tree grows, well, combinatorially, so
// Bernardy turns to showing, basically, that if you prune choice sets
// eagerly by Pareto dominance, you never sacrifice the optimal
// layout, and the state space stays tightly bounded and roughly
// proportional to the wiggle room allowed by the max column width.
//
// What follows here is a stupid but working implementation of the
// layout search algorithm in Zig that follows Bernardy's "product
// algebra" approach, using the measurement triples to do the actual
// Pareto frontier comparisons while simultaneously also recording the
// corresponding concrete document layout choices, except that instead
// of building lightweight "layout trees" and only later buffering up
// the actual byte contents of the winning layout, this code just does
// all kinds of allocating string concatenation all over the place,
// for some reason that I don't remember anymore.

const std = @import("std");
const Allocator = std.mem.Allocator;

const Style = usize;

/// A styled text segment
pub const Segment = struct {
    text: []const u8,
    style: Style = 0,
};

/// A layout candidate with metrics and styled content
pub const Box = struct {
    /// Text lines, each line is a list of styled segments
    txt: std.ArrayList(std.ArrayList(Segment)) = .empty,
    /// Number of complete lines (not counting final)
    len: u16 = 0,
    /// Length of final incomplete line
    fin: u16,
    /// Maximum line length across all lines
    max: u16,

    pub fn text(bytes: []const u8, style: Style, alloc: Allocator) !Box {
        var line = std.ArrayList(Segment){};
        try line.append(alloc, Segment{ .text = bytes, .style = style });

        var txt = std.ArrayList(std.ArrayList(Segment)){};
        try txt.append(alloc, line);

        return .{
            .txt = txt,
            .fin = @intCast(bytes.len),
            .max = @intCast(bytes.len),
        };
    }

    pub fn deinit(self: *Box, alloc: Allocator) void {
        for (self.txt.items) |*line| line.deinit(alloc);
        self.txt.deinit(alloc);
    }

    pub fn indent(self: Box, n: u16, alloc: Allocator) !Box {
        var result = Box{
            .txt = std.ArrayList(std.ArrayList(Segment)){},
            .len = self.len,
            .fin = self.fin + n,
            .max = self.max + n,
        };

        for (self.txt.items) |line| {
            var new_line = std.ArrayList(Segment){};
            // Add indent as normal-styled spaces
            if (n > 0) {
                const spaces = try alloc.alloc(u8, n);
                @memset(spaces, ' ');
                try new_line.append(alloc, Segment{ .text = spaces, .style = .normal });
            }
            // Copy existing segments
            try new_line.appendSlice(alloc, line.items);
            try result.txt.append(alloc, new_line);
        }

        return result;
    }

    pub fn flush(self: Box, alloc: Allocator) !Box {
        var result = Box{
            .len = self.len + 1,
            .max = self.max,
            .fin = 0,
        };

        try result.txt.appendSlice(alloc, self.txt.items);
        try result.txt.append(alloc, std.ArrayList(Segment){});

        return result;
    }

    pub fn hcat(a: Box, b: Box, alloc: Allocator) !Box {
        var result = Box{
            .len = a.len + b.len,
            .fin = a.fin + b.fin,
            .max = @max(a.max, b.max + a.fin),
        };

        // Copy a's complete lines
        for (a.txt.items[0..a.len]) |line| {
            var new_line = std.ArrayList(Segment){};
            try new_line.appendSlice(alloc, line.items);
            try result.txt.append(alloc, new_line);
        }

        // Merge a's final with b's first
        const last_a = a.txt.items[a.len];
        const first_b = b.txt.items[0];

        var merged = std.ArrayList(Segment){};
        try merged.appendSlice(alloc, last_a.items);
        try merged.appendSlice(alloc, first_b.items);
        try result.txt.append(alloc, merged);

        // Copy b's remaining lines, indented by a's final width
        for (b.txt.items[1 .. b.len + 1]) |line| {
            var new_line = std.ArrayList(Segment){};
            // Add indent
            if (a.fin > 0) {
                const spaces = try alloc.alloc(u8, a.fin);
                @memset(spaces, ' ');
                try new_line.append(alloc, Segment{ .text = spaces });
            }
            try new_line.appendSlice(alloc, line.items);
            try result.txt.append(alloc, new_line);
        }

        return result;
    }

    pub fn vcat(a: Box, b: Box, alloc: Allocator) !Box {
        const flushed = try a.flush(alloc);
        return try flushed.hcat(b, alloc);
    }

    pub fn beats(a: Box, b: Box) bool {
        return a.len <= b.len and a.max <= b.max and a.fin <= b.fin;
    }

    /// Render to segments (for styled output)
    pub fn renderSegments(self: Box, alloc: Allocator) ![]const Segment {
        var result = std.ArrayList(Segment){};

        for (self.txt.items, 0..) |line, i| {
            if (i > 0) {
                try result.append(alloc, Segment{ .text = "\n" });
            }
            try result.appendSlice(alloc, line.items);
        }

        return result.toOwnedSlice(alloc);
    }

    /// Render to plain string (for non-styled output)
    pub fn renderPlain(self: Box, alloc: Allocator) ![]const u8 {
        var result = std.ArrayList(u8){};

        for (self.txt.items, 0..) |line, i| {
            if (i > 0) try result.append(alloc, '\n');
            for (line.items) |seg| {
                try result.appendSlice(alloc, seg.text);
            }
        }

        return result.toOwnedSlice(alloc);
    }
};

pub const Doc = []const Box;

pub fn pareto(boxes: []const Box, alloc: Allocator) !Doc {
    var result = std.ArrayList(Box){};

    boxloop: for (boxes) |x| {
        for (result.items) |a| {
            if (a.beats(x)) continue :boxloop;
        }

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

pub fn text(bytes: []const u8, style: anytype, alloc: Allocator) !Doc {
    const box = try Box.text(bytes, @intFromEnum(style), alloc);
    const result = try alloc.alloc(Box, 1);
    result[0] = box;
    return result;
}

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

pub fn flush(a: Doc, alloc: Allocator) !Doc {
    var result = std.ArrayList(Box){};
    for (a) |x| {
        try result.append(alloc, try x.flush(alloc));
    }
    return result.toOwnedSlice(alloc);
}

pub fn vcat(max_width: u16, a: Doc, b: Doc, alloc: Allocator) !Doc {
    return hcat(max_width, try flush(a, alloc), b, alloc);
}

pub fn cat(max_width: u16, a: Doc, b: Doc, alloc: Allocator) !Doc {
    const h = try hcat(max_width, a, b, alloc);
    const v = try vcat(max_width, a, b, alloc);

    var candidates = std.ArrayList(Box){};
    try candidates.appendSlice(alloc, h);
    try candidates.appendSlice(alloc, v);

    return pareto(candidates.items, alloc);
}

fn selectBest(max_width: u16, a: Box, b: Box) bool {
    const a_fits = a.max <= max_width;
    const b_fits = b.max <= max_width;

    if (a_fits and !b_fits) return true;
    if (b_fits and !a_fits) return false;

    if (a_fits and b_fits) {
        return a.len < b.len;
    } else {
        return a.max < b.max;
    }
}

/// Render document to styled segments (picks best layout)
pub fn renderSegments(doc: Doc, max_width: u16, alloc: Allocator) !?[]const Segment {
    if (std.sort.min(Box, doc, max_width, selectBest)) |best| {
        return try best.renderSegments(alloc);
    }
    return null;
}

/// Render document to plain string (picks best layout)
pub fn renderPlain(doc: Doc, max_width: u16, alloc: Allocator) !?[]const u8 {
    if (std.sort.min(Box, doc, max_width, selectBest)) |best| {
        return try best.renderPlain(alloc);
    }
    return null;
}

pub fn deinit(doc: Doc, alloc: Allocator) void {
    for (doc) |*box| {
        var mutable = box.*;
        mutable.deinit(alloc);
    }
    alloc.free(doc);
}

test "styled text" {
    const SDP = @This();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const S = enum { a, b };
    const hello = try SDP.text("hello", S.a, alloc);
    const world = try SDP.text("world", S.b, alloc);
    const doc = try SDP.cat(80, hello, world, alloc);
    const segs = (try SDP.renderSegments(doc, 80, alloc)).?;

    // Should have 2 segments
    try std.testing.expectEqual(@as(usize, 2), segs.len);
    try std.testing.expectEqual(@intFromEnum(S.a), segs[0].style);
    try std.testing.expectEqual(@intFromEnum(S.b), segs[1].style);
}
