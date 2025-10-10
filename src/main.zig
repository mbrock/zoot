const std = @import("std");
const pp = @import("zoot").PrettyGoodMachine;
const viz = @import("zoot").PrettyViz;

const nl = pp.Node.nl;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buffer: [8192]u8 = undefined;
    var stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&buffer);
    const writer = &stdout_writer.interface;
    defer writer.flush() catch {};

    var t = pp.Tree.init(allocator);
    defer t.deinit();

    const arg_prepare = try t.text("prepare_inputs()");

    const arg_config_choice = try t.fork(
        try t.text("load_config()"),
        try t.pile(&.{
            try t.text("load_config {"),
            try t.nest(4, try t.pile(&.{
                try t.text("lookup_env();"),
                try t.text("read_disk();"),
            })),
            try t.text("}"),
        }),
    );

    const arg_execute_choice = try t.fork(
        try t.text("execute()"),
        try t.pile(&.{
            try t.text("execute("),
            try t.nest(4, try t.pile(&.{
                try t.cat(&.{
                    try t.text("stage("),
                    try t.sepBy(
                        &.{
                            try t.text("compile"),
                            try t.text("test"),
                            try t.text("package"),
                        },
                        try t.text(", "),
                    ),
                    try t.text(");"),
                }),
                try t.text("deploy();"),
            })),
            try t.text(")"),
        }),
    );

    const pipeline_choice = try t.fork(
        try t.cat(&.{
            try t.text("pipeline("),
            try t.commatize(
                &.{
                    arg_prepare,
                    arg_config_choice,
                    arg_execute_choice,
                },
            ),
            try t.text(")"),
        }),
        try t.pile(&.{
            try t.text("pipeline("),
            try t.nest(4, try t.sepBy(
                &.{
                    arg_prepare,
                    arg_config_choice,
                    arg_execute_choice,
                },
                nl,
            )),
            try t.text(")"),
        }),
    );

    const binding_choice = try t.fork(
        try t.cat(&.{
            try t.text("let result = "),
            pipeline_choice,
            try t.text(";"),
        }),
        try t.pile(&.{
            try t.plus(try t.text("let result = "), pipeline_choice),
            try t.text("log(result);"),
            try t.text("audit(result);"),
        }),
    );

    const return_choice = try t.fork(
        try t.text("return finalize(result);"),
        try t.pile(&.{
            try t.text("return finalize("),
            try t.nest(4, try t.pile(&.{
                try t.text("result"),
                try t.text("// TODO: handle retries"),
            })),
            try t.text(");"),
        }),
    );

    const demo_doc = try t.fork(
        try t.cat(&.{
            try t.text("task build { "),
            binding_choice,
            try t.text(" "),
            return_choice,
            try t.text(" }"),
        }),
        try t.pile(&.{
            try t.text("task build {"),
            try t.nest(4, try t.sepBy(
                &.{
                    binding_choice,
                    return_choice,
                },
                nl,
            )),
            try t.text("}"),
        }),
    );

    var best = try t.best(allocator, pp.F1.init(20), demo_doc, writer);
    defer best.deinit(allocator);

    try writer.writeAll("\nbest layout (width 20):\n");
    try t.renderWithPath(writer, demo_doc, &best);
    try writer.writeByte('\n');

    {
        const file = try std.fs.cwd().createFile("graphviz.dot", .{});
        defer file.close();
        var sink = file.writer(&buffer);
        try viz.graphviz(&t, &sink.interface, demo_doc);
    }

    {
        const file = try std.fs.cwd().createFile("tree.json", .{});
        defer file.close();
        var sink = file.writer(&buffer);
        try viz.toJson(&t, &sink.interface, demo_doc);
    }

    try writer.writeAll("Generated graphviz.dot\n");
    try writer.writeAll("Generated tree.json\n");
    try writer.writeAll("Run: dot -Tpdf graphviz.dot -o graphviz.pdf\n");
}
