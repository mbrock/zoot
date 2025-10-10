const std = @import("std");
const pretty = @import("zoot").PrettyGoodMachine;
const viz = @import("zoot").PrettyViz;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buffer: [8192]u8 = undefined;
    var stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&buffer);
    const writer = &stdout_writer.interface;
    defer writer.flush() catch {};

    var demo_tree = pretty.Tree.init(allocator);
    defer demo_tree.deinit();

    const arg_prepare = try demo_tree.text("prepare_inputs()");

    const arg_config_flat = try demo_tree.text("load_config()");
    const arg_config_block = try demo_tree.cat(&.{
        try demo_tree.text("load_config {"),
        pretty.Node.nl,
        try demo_tree.nest(4, try demo_tree.cat(&.{
            try demo_tree.text("lookup_env();"),
            pretty.Node.nl,
            try demo_tree.text("read_disk();"),
        })),
        pretty.Node.nl,
        try demo_tree.text("}"),
    });
    const arg_config_choice = try demo_tree.fork(arg_config_flat, arg_config_block);

    const arg_execute_inline = try demo_tree.text("execute()");
    const arg_execute_block = try demo_tree.cat(&.{
        try demo_tree.text("execute("),
        pretty.Node.nl,
        try demo_tree.nest(4, try demo_tree.cat(&.{
            try demo_tree.text("stage("),
            try demo_tree.sepBy(&.{ try demo_tree.text("compile"), try demo_tree.text("test"), try demo_tree.text("package") }, try demo_tree.text(", ")),
            try demo_tree.text(");"),
            pretty.Node.nl,
            try demo_tree.text("deploy();"),
        })),
        pretty.Node.nl,
        try demo_tree.text(")"),
    });
    const arg_execute_choice = try demo_tree.fork(arg_execute_inline, arg_execute_block);

    const inline_args = try demo_tree.sepBy(&.{ arg_prepare, arg_config_choice, arg_execute_choice }, try demo_tree.text(", "));
    const inline_pipeline = try demo_tree.cat(&.{
        try demo_tree.text("pipeline("),
        inline_args,
        try demo_tree.text(")"),
    });

    const vertical_args = try demo_tree.sepBy(&.{ arg_prepare, arg_config_choice, arg_execute_choice }, pretty.Node.nl);
    const vertical_pipeline = try demo_tree.cat(&.{
        try demo_tree.text("pipeline("),
        pretty.Node.nl,
        try demo_tree.nest(4, vertical_args),
        pretty.Node.nl,
        try demo_tree.text(")"),
    });

    const pipeline_choice = try demo_tree.fork(inline_pipeline, vertical_pipeline);

    const binding_inline = try demo_tree.cat(&.{
        try demo_tree.text("let result = "),
        pipeline_choice,
        try demo_tree.text(";"),
    });

    const binding_block = try demo_tree.cat(&.{
        try demo_tree.text("let result = "),
        pipeline_choice,
        pretty.Node.nl,
        try demo_tree.text("log(result);"),
        pretty.Node.nl,
        try demo_tree.text("audit(result);"),
    });
    const binding_choice = try demo_tree.fork(binding_inline, binding_block);

    const return_inline = try demo_tree.text("return finalize(result);");
    const return_block = try demo_tree.cat(&.{
        try demo_tree.text("return finalize("),
        pretty.Node.nl,
        try demo_tree.nest(4, try demo_tree.cat(&.{
            try demo_tree.text("result"),
            pretty.Node.nl,
            try demo_tree.text("// TODO: handle retries"),
        })),
        pretty.Node.nl,
        try demo_tree.text(");"),
    });
    const return_choice = try demo_tree.fork(return_inline, return_block);

    const inline_block = try demo_tree.cat(&.{
        try demo_tree.text("task build { "),
        binding_choice,
        try demo_tree.text(" "),
        return_choice,
        try demo_tree.text(" }"),
    });

    const block_body = try demo_tree.sepBy(&.{ binding_choice, return_choice }, pretty.Node.nl);
    const vertical_block = try demo_tree.cat(&.{
        try demo_tree.text("task build {"),
        pretty.Node.nl,
        try demo_tree.nest(4, block_body),
        pretty.Node.nl,
        try demo_tree.text("}"),
    });

    const demo_doc = try demo_tree.fork(inline_block, vertical_block);

    try writer.writeAll("Maze trace\n");
    const trace_writer: ?*std.Io.Writer = writer;
    var best_demo = try demo_tree.mazeBest(allocator, pretty.F1.init(20), demo_doc, trace_writer);
    defer best_demo.path.deinit(allocator);

    try writer.writeAll("\nMaze best layout (width 20):\n");
    try demo_tree.renderWithPath(writer, demo_doc, &best_demo.path);
    try writer.writeByte('\n');
    try writer.print("score: overflow={d} lines={d}\n\n", .{ best_demo.rank.o, best_demo.rank.h });

    // Produce the original visualization example.
    var tree = pretty.Tree.init(allocator);
    defer tree.deinit();

    const condition = try tree.cat(&.{
        try tree.text("x"),
        try tree.text(" "),
        try tree.text(">"),
        try tree.text(" "),
        try tree.text("0"),
    });

    const call1_args = try tree.cat(&.{
        try tree.text("alpha"),
        try tree.text(","),
        try tree.fork(
            try tree.text(" "),
            try tree.plus(pretty.Node.nl, try tree.text("  ")),
        ),
        try tree.text("beta"),
    });

    const call1 = try tree.cat(&.{
        try tree.text("fooFunction"),
        try tree.parens(call1_args),
        try tree.text(";"),
    });

    const call2 = try tree.cat(&.{
        try tree.text("barFunction"),
        try tree.text("()"),
        try tree.text(";"),
    });

    const body = try tree.sepBy(&.{ call1, call2 }, try tree.fork(
        try tree.text(" "),
        pretty.Node.nl,
    ));

    const if_stmt = try tree.cat(&.{
        try tree.text("if"),
        try tree.text(" "),
        try tree.parens(condition),
        try tree.text(" "),
        try tree.braces(try tree.cat(&.{
            try tree.fork(try tree.text(" "), pretty.Node.nl),
            try tree.nest(2, body),
            try tree.fork(try tree.text(" "), pretty.Node.nl),
        })),
    });

    var dot_buffer: [65536]u8 = undefined;
    const dot = try viz.graphviz(&tree, &dot_buffer, if_stmt);
    const dot_file = try std.fs.cwd().createFile("graphviz.dot", .{});
    defer dot_file.close();
    try dot_file.writeAll(dot);

    var json_buffer: [65536]u8 = undefined;
    const json = try viz.toJson(&tree, &json_buffer, if_stmt);
    const json_file = try std.fs.cwd().createFile("tree.json", .{});
    defer json_file.close();
    try json_file.writeAll(json);

    try writer.print("Generated graphviz.dot with {d} bytes\n", .{dot.len});
    try writer.print("Generated tree.json with {d} bytes\n", .{json.len});
    try writer.writeAll("Run: dot -Tpdf graphviz.dot -o graphviz.pdf\n");
}
