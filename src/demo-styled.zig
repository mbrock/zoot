const std = @import("std");
const zoot = @import("zoot");
const builtin = @import("builtin");

const Style = zoot.StructPrinter.Style;

const WIDTH = 78;

pub fn main() !void {
    var buffer: [4096]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const writer = &stdout.interface;
    defer writer.flush() catch {};

    const tty = std.Io.tty.detectConfig(std.fs.File.stdout());

    // Set up color theme
    var theme = zoot.ColorPrinter.ColorPrinter(Style).Theme.init(.{});
    theme.put(.number, zoot.ColorPrinter.SGR.fg(.cyan));
    theme.put(.string, zoot.ColorPrinter.SGR.fg(.green));
    theme.put(.keyword, zoot.ColorPrinter.SGR.fg(.magenta));
    theme.put(.field_name, zoot.ColorPrinter.SGR.fg(.yellow));
    theme.put(.type_name, zoot.ColorPrinter.SGR.fg(.blue).bold());

    var color = zoot.ColorPrinter.ColorPrinter(Style).init(writer, tty, theme);

    const ruler = "═" ** WIDTH;

    // Big runtime struct example
    try writer.writeAll("std.builtin.target @ 78 cols:\n");
    try writer.writeAll(ruler ++ "\n");
    try zoot.StructPrinter.printStyled(
        @TypeOf(builtin.target),
        builtin.target,
        std.heap.page_allocator,
        writer,
        &color,
        .{ .max_width = WIDTH },
    );
    try writer.writeAll("\n\n");

    // Complex nested runtime struct
    const Address = struct {
        street: []const u8,
        city: []const u8,
        state: []const u8,
        zip: u32,
        country: []const u8,
    };

    const Contact = struct {
        email: []const u8,
        phone: []const u8,
        preferred_method: enum { email, phone, sms },
    };

    const Person = struct {
        name: []const u8,
        age: u32,
        address: Address,
        work_address: ?Address,
        contact: Contact,
        tags: []const []const u8,
        active: bool,
        metadata: struct {
            created: u64,
            updated: u64,
            version: u32,
        },
    };

    const person = Person{
        .name = "Alice Johnson",
        .age = 32,
        .address = Address{
            .street = "123 Main Street, Apartment 4B",
            .city = "San Francisco",
            .state = "CA",
            .zip = 94102,
            .country = "USA",
        },
        .work_address = Address{
            .street = "456 Tech Boulevard, Suite 1000",
            .city = "Palo Alto",
            .state = "CA",
            .zip = 94301,
            .country = "USA",
        },
        .contact = Contact{
            .email = "alice.johnson@example.com",
            .phone = "+1-555-0123",
            .preferred_method = .email,
        },
        .tags = &[_][]const u8{ "engineering", "senior", "backend", "distributed-systems" },
        .active = true,
        .metadata = .{
            .created = 1704067200,
            .updated = 1704153600,
            .version = 5,
        },
    };

    try writer.writeAll("Complex runtime nested struct @ 78 cols:\n");
    try writer.writeAll(ruler ++ "\n");
    try zoot.StructPrinter.printStyled(
        Person,
        person,
        std.heap.page_allocator,
        writer,
        &color,
        .{ .max_width = WIDTH },
    );
    try writer.writeAll("\n\n");

    // Complex runtime union
    const Value = union(enum) {
        none: void,
        boolean: bool,
        number: f64,
        string: []const u8,
        point: struct { x: f64, y: f64 },
        rect: struct { x: f64, y: f64, w: f64, h: f64 },
    };

    try writer.writeAll("Tagged union @ 78 cols:\n");
    try writer.writeAll(ruler ++ "\n");
    try zoot.StructPrinter.printStyled(
        Value,
        Value{ .rect = .{ .x = 10.5, .y = 20.3, .w = 100.0, .h = 75.5 } },
        std.heap.page_allocator,
        writer,
        &color,
        .{ .max_width = WIDTH },
    );
    try writer.writeAll("\n\n");

    // Comptime: typeInfo
    try writer.writeAll("@typeInfo(std.builtin.Type.Fn) @ 78 cols (comptime):\n");
    try writer.writeAll(ruler ++ "\n");
    {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const tmp = arena.allocator();

        const type_info = @typeInfo(std.builtin.Type.Fn);
        const doc = try zoot.StructPrinter.prettyComptime(
            @TypeOf(type_info),
            type_info,
            tmp,
            .{ .max_width = WIDTH, .max_depth = 10 },
        );
        const StyledDocPrinter = zoot.StyledDocPrinter;
        const segments = (try StyledDocPrinter.renderSegments(doc, WIDTH, tmp)) orelse return;

        for (segments) |seg| {
            try writer.splatByteAll(' ', seg.tab);
            if (color.theme.get(@enumFromInt(seg.ink))) |_| {
                try color.print(@enumFromInt(seg.ink), "{s}", .{seg.txt});
            } else {
                try writer.writeAll(seg.txt);
            }
        }
    }
    try writer.writeAll("\n\n");

    // Narrower layout demo
    const narrow_width = 50;
    const narrow_ruler = "═" ** narrow_width;

    try writer.writeAll("Same Person struct @ 50 cols (narrow):\n");
    try writer.writeAll(narrow_ruler ++ "\n");
    try zoot.StructPrinter.printStyled(
        Person,
        person,
        std.heap.page_allocator,
        writer,
        &color,
        .{ .max_width = narrow_width },
    );
    try writer.writeAll("\n");
}
