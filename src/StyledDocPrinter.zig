// Optimal pretty printing with styling support
// Based on Bernardy 2017 but with styled text segments

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn StyledDocPrinter(comptime Style: type) type {
    return struct {
        /// A styled text segment
        pub const Segment = struct {
            text: []const u8,
            style: Style,
        };

        /// A layout candidate with metrics and styled content
        pub const Box = struct {
            /// Text lines, each line is a list of styled segments
            txt: std.ArrayList(std.ArrayList(Segment)),
            /// Number of complete lines (not counting final)
            lines: u16,
            /// Length of final incomplete line
            final: u16,
            /// Maximum line length across all lines
            max: u16,

            pub fn text(bytes: []const u8, style: Style, alloc: Allocator) !Box {
                var line = std.ArrayList(Segment){};
                try line.append(alloc, Segment{ .text = bytes, .style = style });

                var txt = std.ArrayList(std.ArrayList(Segment)){};
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

            pub fn indent(self: Box, n: u16, alloc: Allocator) !Box {
                var result = Box{
                    .txt = std.ArrayList(std.ArrayList(Segment)){},
                    .lines = self.lines,
                    .final = self.final + n,
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
                    .txt = std.ArrayList(std.ArrayList(Segment)){},
                    .lines = self.lines + 1,
                    .max = self.max,
                    .final = 0,
                };

                try result.txt.appendSlice(alloc, self.txt.items);
                try result.txt.append(alloc, std.ArrayList(Segment){});

                return result;
            }

            pub fn hcat(a: Box, b: Box, alloc: Allocator) !Box {
                var result = Box{
                    .txt = std.ArrayList(std.ArrayList(Segment)){},
                    .lines = a.lines + b.lines,
                    .final = a.final + b.final,
                    .max = @max(a.max, b.max + a.final),
                };

                // Copy a's complete lines
                for (a.txt.items[0..a.lines]) |line| {
                    var new_line = std.ArrayList(Segment){};
                    try new_line.appendSlice(alloc, line.items);
                    try result.txt.append(alloc, new_line);
                }

                // Merge a's final with b's first
                const last_a = a.txt.items[a.lines];
                const first_b = b.txt.items[0];

                var merged = std.ArrayList(Segment){};
                try merged.appendSlice(alloc, last_a.items);
                try merged.appendSlice(alloc, first_b.items);
                try result.txt.append(alloc, merged);

                // Copy b's remaining lines, indented by a's final width
                for (b.txt.items[1 .. b.lines + 1]) |line| {
                    var new_line = std.ArrayList(Segment){};
                    // Add indent
                    if (a.final > 0) {
                        const spaces = try alloc.alloc(u8, a.final);
                        @memset(spaces, ' ');
                        try new_line.append(alloc, Segment{ .text = spaces, .style = .normal });
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
                return a.lines <= b.lines and a.max <= b.max and a.final <= b.final;
            }

            /// Render to segments (for styled output)
            pub fn renderSegments(self: Box, alloc: Allocator) ![]const Segment {
                var result = std.ArrayList(Segment){};

                for (self.txt.items, 0..) |line, i| {
                    if (i > 0) {
                        try result.append(alloc, Segment{ .text = "\n", .style = .normal });
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

        pub fn text(bytes: []const u8, style: Style, alloc: Allocator) !Doc {
            const box = try Box.text(bytes, style, alloc);
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
                return a.lines < b.lines;
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
    };
}

test "styled text" {
    const Style = enum { normal, keyword, string };
    const SDP = StyledDocPrinter(Style);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const hello = try SDP.text("hello", .keyword, alloc);
    const world = try SDP.text("world", .string, alloc);
    const doc = try SDP.cat(80, hello, world, alloc);
    const segs = (try SDP.renderSegments(doc, 80, alloc)).?;

    // Should have 2 segments
    try std.testing.expectEqual(@as(usize, 2), segs.len);
    try std.testing.expectEqual(Style.keyword, segs[0].style);
    try std.testing.expectEqual(Style.string, segs[1].style);
}
