const std = @import("std");
const pretty = @import("pretty.zig");

/// Binary heap dump format - trivial because Rack contains no pointers!
/// Format:
///   [8 bytes: magic "ZOOTHEAP"]
///   [u64: total_byte_length (excluding magic and this length)]
///   [u64: step_number (or 0xffffffffffffffff for non-temporal dump)]
///   [u32: hcat.len]
///   [u32: fork.len]
///   [u32: cons.len]
///   [u32: ktx1.len]
///   [u32: ktx2.len]
///   [u32: ktx3.len]
///   [u32: ktx4.len]
///   [u32: duel.len]
///   [u32: cope.len]
///   [hcat array raw bytes]
///   [fork array raw bytes]
///   [cons array raw bytes]
///   [ktx1 array raw bytes]
///   [ktx2 array raw bytes]
///   [ktx3 array raw bytes]
///   [ktx4 array raw bytes]
///   [duel array raw bytes]
///   [cope array raw bytes]

pub const HEAP_MAGIC = "ZOOTHEAP";
pub const NO_STEP = 0xffffffffffffffff;

pub fn dumpHeap(writer: *std.Io.Writer, half: *const pretty.Half, step: ?u64) !void {
    // Write magic
    try writer.writeAll(HEAP_MAGIC);

    // Calculate total size using comptime reflection
    const fields = @typeInfo(pretty.Half).@"struct".fields;
    var total_size: usize = 8 + fields.len * 4; // step + lengths
    inline for (fields) |field| {
        const rack = &@field(half, field.name);
        const items = rack.list.items;
        total_size += items.len * @sizeOf(@TypeOf(items[0]));
    }

    // Write total length and step
    try writer.writeInt(u64, total_size, .little);
    try writer.writeInt(u64, step orelse NO_STEP, .little);

    // Write lengths using comptime iteration
    inline for (fields) |field| {
        const rack = &@field(half, field.name);
        try writer.writeInt(u32, @intCast(rack.list.items.len), .little);
    }

    // Write raw array data - no conversion needed!
    inline for (fields) |field| {
        const rack = &@field(half, field.name);
        try writer.writeAll(std.mem.sliceAsBytes(rack.list.items));
    }
}

/// Streaming trace format
/// Format:
///   [8 bytes: magic "ZOOTRACE"]
///   Then repeating event records:
///   [u8: event_type]
///   [u64: step]
///   [payload based on event_type]
///
/// Event types:
///   0: gc_start (payload: u32 heap_size)
///   1: gc_forward (payload: u32 old_node, u32 new_node)
///   2: heap_snapshot (payload: full heap dump as above, minus magic/total_size)
///   3: gc_end (payload: u32 heap_size)

pub const TRACE_MAGIC = "ZOOTRACE";

pub const EventType = enum(u8) {
    gc_start = 0,
    gc_forward = 1,
    heap_snapshot = 2,
    gc_end = 3,
};

pub const BinaryTrace = struct {
    file: std.fs.File,
    file_writer: std.fs.File.Writer,
    buffer: [8192]u8 = undefined,
    step: u64 = 0,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*BinaryTrace {
        // Ensure directory exists
        std.fs.cwd().makeDir(".heapdumps") catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        const file = try std.fs.cwd().createFile(".heapdumps/trace.bin", .{});

        const trace = try allocator.create(BinaryTrace);
        trace.buffer = undefined;
        trace.file_writer = file.writer(&trace.buffer);

        trace.* = BinaryTrace{
            .file = file,
            .file_writer = trace.file_writer,
            .buffer = trace.buffer,
            .step = 0,
            .allocator = allocator,
        };

        // Write magic header using Writer interface
        const writer = &trace.file_writer.interface;
        try writer.writeAll(TRACE_MAGIC);
        try writer.flush();

        return trace;
    }

    pub fn deinit(self: *BinaryTrace) void {
        self.flush() catch {};
        self.file.close();
        self.allocator.destroy(self);
    }

    pub fn flush(self: *BinaryTrace) !void {
        const writer = &self.file_writer.interface;
        try writer.flush();
    }

    pub fn emitGCStart(self: *BinaryTrace, heap_size: usize) !void {
        const writer = &self.file_writer.interface;
        try writer.writeInt(u8, @intFromEnum(EventType.gc_start), .little);
        try writer.writeInt(u64, self.step, .little);
        try writer.writeInt(u32, @intCast(heap_size), .little);
        try writer.flush();
    }

    pub fn emitGCForward(self: *BinaryTrace, old_node: pretty.Node, new_node: pretty.Node) !void {
        const writer = &self.file_writer.interface;
        try writer.writeInt(u8, @intFromEnum(EventType.gc_forward), .little);
        try writer.writeInt(u64, self.step, .little);
        try writer.writeInt(u32, @bitCast(old_node), .little);
        try writer.writeInt(u32, @bitCast(new_node), .little);
        try writer.flush();
    }

    pub fn emitHeapSnapshot(self: *BinaryTrace, half: *const pretty.Half) !void {
        const writer = &self.file_writer.interface;
        try writer.writeInt(u8, @intFromEnum(EventType.heap_snapshot), .little);
        try writer.writeInt(u64, self.step, .little);

        // Write lengths using comptime iteration
        const fields = @typeInfo(pretty.Half).@"struct".fields;
        inline for (fields) |field| {
            const rack = &@field(half, field.name);
            try writer.writeInt(u32, @intCast(rack.list.items.len), .little);
        }

        // Write raw array data
        inline for (fields) |field| {
            const rack = &@field(half, field.name);
            try writer.writeAll(std.mem.sliceAsBytes(rack.list.items));
        }

        try writer.flush();
    }

    pub fn emitGCEnd(self: *BinaryTrace, heap_size: usize) !void {
        const writer = &self.file_writer.interface;
        try writer.writeInt(u8, @intFromEnum(EventType.gc_end), .little);
        try writer.writeInt(u64, self.step, .little);
        try writer.writeInt(u32, @intCast(heap_size), .little);
        try writer.flush();
        self.step += 1;
    }
};
