const std = @import("std");
const swi = @import("swi.zig");
const zoot = @import("zoot");
const pretty = zoot.PrettyGoodMachine;
const heap_binary = zoot.heap_binary;

// Global trace reader state
var trace_file: ?std.fs.File = null;
var trace_gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};

// Global Loop state for step-by-step execution
// Loop state is now stored in BLOBs, not globals!
// Keep these for backward compatibility with step_once:
var loop_state: ?*pretty.Loop = null;
var loop_tree: ?*pretty.Tree = null;
var current_exec: ?pretty.Exec = null;

// BLOB type for Loop state
fn loop_blob_release(a: swi.atom_t) callconv(.c) c_int {
    var len: usize = 0;
    var type_ptr: [*c]swi.PL_blob_t = null;
    const ptr = swi.PL_blob_data(a, &len, &type_ptr);
    if (ptr) |p| {
        const loop: *pretty.Loop = @ptrCast(@alignCast(p));
        loop.deinit();
        build_gpa.allocator().destroy(loop);
    }
    return 1;
}

extern "c" fn fprintf(stream: ?*anyopaque, format: [*:0]const u8, ...) c_int;

fn loop_blob_write(s: ?*swi.IOSTREAM, a: swi.atom_t, flags: c_int) callconv(.c) c_int {
    _ = flags;
    _ = a;
    _ = fprintf(s, "<loop>");
    return 1;
}

var loop_blob_type = swi.PL_blob_t{
    .magic = swi.PL_BLOB_MAGIC,
    .flags = swi.PL_BLOB_UNIQUE | swi.PL_BLOB_NOCOPY,
    .name = "loop",
    .release = loop_blob_release,
    .write = loop_blob_write,
    .compare = null,
    .acquire = null,
    .save = null,
    .load = null,
    .padding = 0,
    .reserved = [_]?*anyopaque{null} ** 9,
    .registered = 0,
    .rank = 0,
    .next = null,
    .atom_name = 0,
};

// Global Tree for building nodes from Prolog
var build_tree: ?*pretty.Tree = null;
var build_gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};

// Generic comptime struct to Prolog term converter
fn structToTerm(comptime T: type, value: T, term: swi.term_t) !void {
    const type_info = @typeInfo(T);

    switch (type_info) {
        .@"struct" => |struct_info| {
            // Create functor name from struct name (lowercase for Prolog)
            const struct_name = @typeName(T);
            // Find just the type name after the last '.'
            const simple_name = blk: {
                var i: usize = struct_name.len;
                while (i > 0) {
                    i -= 1;
                    if (struct_name[i] == '.') {
                        break :blk struct_name[i + 1 ..];
                    }
                }
                break :blk struct_name;
            };

            // Create lowercase name for Prolog (avoid capital initial = variable)
            var name_buf: [256]u8 = undefined;
            for (simple_name, 0..) |c, i| {
                name_buf[i] = std.ascii.toLower(c);
            }
            const prolog_name = name_buf[0..simple_name.len];

            // Create atom and functor
            const atom = swi.PL_new_atom_nchars(prolog_name.len, prolog_name.ptr);
            const functor = swi.PL_new_functor(atom, @intCast(struct_info.fields.len));

            // Put functor on term
            _ = swi.PL_put_functor(term, functor);

            // Unify each field
            inline for (struct_info.fields, 0..) |field, idx| {
                const arg_term = swi.PL_new_term_ref();
                _ = swi.PL_unify_arg(@intCast(idx + 1), term, arg_term);

                const field_value = @field(value, field.name);
                try fieldToTerm(field.type, field_value, arg_term);
            }
        },
        else => {
            return error.UnsupportedType;
        },
    }
}

// Cached functors for common types
var node_functor: swi.functor_t = 0;
var pair_functor: swi.functor_t = 0;
var duel_functor: swi.functor_t = 0;
var gist_functor: swi.functor_t = 0;
var rank_functor: swi.functor_t = 0;
var deck_functor: swi.functor_t = 0;
var ktx1_functor: swi.functor_t = 0;
var ktx2_functor: swi.functor_t = 0;
var ktx3_functor: swi.functor_t = 0;
var ktx4_functor: swi.functor_t = 0;
var cope_functor: swi.functor_t = 0;
var item_functor: swi.functor_t = 0;
var kont_functor: swi.functor_t = 0;
var crux_functor: swi.functor_t = 0;
var frob_functor: swi.functor_t = 0;

fn initFunctors() void {
    if (node_functor == 0) {
        node_functor = swi.PL_new_functor(swi.PL_new_atom("node"), 1);
        pair_functor = swi.PL_new_functor(swi.PL_new_atom("pair"), 2);
        duel_functor = swi.PL_new_functor(swi.PL_new_atom("duel"), 3);
        gist_functor = swi.PL_new_functor(swi.PL_new_atom("gist"), 3);
        rank_functor = swi.PL_new_functor(swi.PL_new_atom("rank"), 2);
        deck_functor = swi.PL_new_functor(swi.PL_new_atom("deck"), 3);
        ktx1_functor = swi.PL_new_functor(swi.PL_new_atom("ktx1"), 4);
        ktx2_functor = swi.PL_new_functor(swi.PL_new_atom("ktx2"), 3);
        ktx3_functor = swi.PL_new_functor(swi.PL_new_atom("ktx3"), 3);
        ktx4_functor = swi.PL_new_functor(swi.PL_new_atom("ktx4"), 7);
        cope_functor = swi.PL_new_functor(swi.PL_new_atom("cope"), 2);
        item_functor = swi.PL_new_functor(swi.PL_new_atom("item"), 3);
        kont_functor = swi.PL_new_functor(swi.PL_new_atom("kont"), 3);
        crux_functor = swi.PL_new_functor(swi.PL_new_atom("crux"), 4);
        frob_functor = swi.PL_new_functor(swi.PL_new_atom("frob"), 2);
    }
}

// Helper: convert Node to Prolog term node(repr)
// Use PL_put/cons to build, then unify with the output term
fn nodeToTerm(node: pretty.Node, term: swi.term_t) void {
    initFunctors();
    const temp = swi.PL_new_term_ref();
    const arg = swi.PL_new_term_ref();

    _ = swi.PL_put_int64(arg, @intCast(node.repr()));
    _ = swi.PL_cons_functor(temp, node_functor, arg);
    _ = swi.PL_unify(term, temp);
}

// Helper: convert Pair struct to Prolog term pair(node(X), node(Y))
fn pairToTerm(pair: pretty.Pair, term: swi.term_t) void {
    initFunctors();
    const temp = swi.PL_new_term_ref();
    const head = swi.PL_new_term_ref();
    const tail = swi.PL_new_term_ref();

    nodeToTerm(pair.head, head);
    nodeToTerm(pair.tail, tail);

    _ = swi.PL_cons_functor(temp, pair_functor, head, tail);
    _ = swi.PL_unify(term, temp);
}

// Helper: convert Rank to rank(o, h)
fn rankToTerm(rank: pretty.Rank, term: swi.term_t) void {
    initFunctors();
    const temp = swi.PL_new_term_ref();
    const o_term = swi.PL_new_term_ref();
    const h_term = swi.PL_new_term_ref();

    _ = swi.PL_put_int64(o_term, @intCast(rank.o));
    _ = swi.PL_put_int64(h_term, @intCast(rank.h));

    _ = swi.PL_cons_functor(temp, rank_functor, o_term, h_term);
    _ = swi.PL_unify(term, temp);
}

// Helper: convert Gist to gist(last, rows, rank(o, h))
fn gistToTerm(gist: pretty.Gist, term: swi.term_t) void {
    initFunctors();
    const temp = swi.PL_new_term_ref();
    const last = swi.PL_new_term_ref();
    const rows = swi.PL_new_term_ref();
    const rank = swi.PL_new_term_ref();

    _ = swi.PL_put_int64(last, @intCast(gist.last));
    _ = swi.PL_put_int64(rows, @intCast(gist.rows));
    rankToTerm(gist.rank, rank);

    _ = swi.PL_cons_functor(temp, gist_functor, last, rows, rank);
    _ = swi.PL_unify(term, temp);
}

// Helper: convert Deck to deck(flip, cope, item)
fn deckToTerm(deck: pretty.Deck, term: swi.term_t) void {
    initFunctors();
    const temp = swi.PL_new_term_ref();
    const flip = swi.PL_new_term_ref();
    const cope = swi.PL_new_term_ref();
    const item = swi.PL_new_term_ref();

    _ = swi.PL_put_int64(flip, @intCast(deck.flip));
    _ = swi.PL_put_int64(cope, @intCast(deck.cope));
    _ = swi.PL_put_int64(item, @intCast(deck.item));

    _ = swi.PL_cons_functor(temp, deck_functor, flip, cope, item);
    _ = swi.PL_unify(term, temp);
}

// Helper: convert Duel to duel(node, gist, next)
fn duelToTerm(duel: pretty.Duel, term: swi.term_t) void {
    initFunctors();
    const temp = swi.PL_new_term_ref();
    const node = swi.PL_new_term_ref();
    const gist = swi.PL_new_term_ref();
    const next = swi.PL_new_term_ref();

    nodeToTerm(duel.node, node);
    gistToTerm(duel.gist, gist);
    deckToTerm(duel.next, next);

    _ = swi.PL_cons_functor(temp, duel_functor, node, gist, next);
    _ = swi.PL_unify(term, temp);
}

// Helper: convert Item to item(node, head, base)
fn itemToTerm(item: pretty.Item, term: swi.term_t) void {
    initFunctors();
    const temp = swi.PL_new_term_ref();
    const node = swi.PL_new_term_ref();
    const head = swi.PL_new_term_ref();
    const base = swi.PL_new_term_ref();

    nodeToTerm(item.node, node);
    _ = swi.PL_put_int64(head, @intCast(item.head));
    _ = swi.PL_put_int64(base, @intCast(item.base));

    _ = swi.PL_cons_functor(temp, item_functor, node, head, base);
    _ = swi.PL_unify(term, temp);
}

// Helper: convert Kont to kont(kind_atom, flip, item)
fn kontToTerm(kont: pretty.Kont, term: swi.term_t) void {
    initFunctors();
    const temp = swi.PL_new_term_ref();
    const kind = swi.PL_new_term_ref();
    const flip = swi.PL_new_term_ref();
    const item = swi.PL_new_term_ref();

    // Convert kind enum to atom
    const kind_name = switch (kont.kind) {
        .none => "none",
        .head => "head",
        .tail => "tail",
        .fork => "fork",
        .iter => "iter",
    };
    _ = swi.PL_put_atom_chars(kind, kind_name.ptr);
    _ = swi.PL_put_int64(flip, @intCast(kont.flip));
    _ = swi.PL_put_int64(item, @intCast(kont.item));

    _ = swi.PL_cons_functor(temp, kont_functor, kind, flip, item);
    _ = swi.PL_unify(term, temp);
}

// Helper: convert Ktx1 to ktx1(node, base, item, then)
fn ktx1ToTerm(ktx1: pretty.Ktx1, term: swi.term_t) void {
    initFunctors();
    const temp = swi.PL_new_term_ref();
    const node = swi.PL_new_term_ref();
    const base = swi.PL_new_term_ref();
    const item = swi.PL_new_term_ref();
    const then = swi.PL_new_term_ref();

    nodeToTerm(ktx1.node, node);
    _ = swi.PL_put_int64(base, @intCast(ktx1.base));
    itemToTerm(ktx1.item, item);
    kontToTerm(ktx1.then, then);

    _ = swi.PL_cons_functor(temp, ktx1_functor, node, base, item, then);
    _ = swi.PL_unify(term, temp);
}

// Helper: convert Ktx2 to ktx2(head_deck, item, then)
fn ktx2ToTerm(ktx2: pretty.Ktx2, term: swi.term_t) void {
    initFunctors();
    const temp = swi.PL_new_term_ref();
    const head_deck = swi.PL_new_term_ref();
    const item = swi.PL_new_term_ref();
    const then = swi.PL_new_term_ref();

    deckToTerm(ktx2.head_deck, head_deck);
    itemToTerm(ktx2.item, item);
    kontToTerm(ktx2.then, then);

    _ = swi.PL_cons_functor(temp, ktx2_functor, head_deck, item, then);
    _ = swi.PL_unify(term, temp);
}

// Helper: convert Ktx3 to ktx3(left_deck, item, then)
fn ktx3ToTerm(ktx3: pretty.Ktx3, term: swi.term_t) void {
    initFunctors();
    const temp = swi.PL_new_term_ref();
    const left_deck = swi.PL_new_term_ref();
    const item = swi.PL_new_term_ref();
    const then = swi.PL_new_term_ref();

    deckToTerm(ktx3.left_deck, left_deck);
    itemToTerm(ktx3.item, item);
    kontToTerm(ktx3.then, then);

    _ = swi.PL_cons_functor(temp, ktx3_functor, left_deck, item, then);
    _ = swi.PL_unify(term, temp);
}

// Helper: convert Frob to frob(warp, nest)
fn frobToTerm(frob: pretty.Frob, term: swi.term_t) void {
    initFunctors();
    const temp = swi.PL_new_term_ref();
    const warp = swi.PL_new_term_ref();
    const nest = swi.PL_new_term_ref();

    _ = swi.PL_put_int64(warp, @intCast(frob.warp));
    _ = swi.PL_put_int64(nest, @intCast(frob.nest));

    _ = swi.PL_cons_functor(temp, frob_functor, warp, nest);
    _ = swi.PL_unify(term, temp);
}

// Helper: convert Ktx4 to ktx4(current_head, result_deck, tail_node, item, base, frob, then)
fn ktx4ToTerm(ktx4: pretty.Ktx4, term: swi.term_t) void {
    initFunctors();
    const temp = swi.PL_new_term_ref();
    const current_head = swi.PL_new_term_ref();
    const result_deck = swi.PL_new_term_ref();
    const tail_node = swi.PL_new_term_ref();
    const item = swi.PL_new_term_ref();
    const base = swi.PL_new_term_ref();
    const frob = swi.PL_new_term_ref();
    const then = swi.PL_new_term_ref();

    deckToTerm(ktx4.current_head, current_head);
    deckToTerm(ktx4.result_deck, result_deck);
    nodeToTerm(ktx4.tail_node, tail_node);
    itemToTerm(ktx4.item, item);
    _ = swi.PL_put_int64(base, @intCast(ktx4.base));
    frobToTerm(ktx4.frob, frob);
    kontToTerm(ktx4.then, then);

    _ = swi.PL_cons_functor(temp, ktx4_functor, current_head, result_deck, tail_node, item, base, frob, then);
    _ = swi.PL_unify(term, temp);
}

// Helper: convert Crux to crux(last, base, icky, rows)
fn cruxToTerm(crux: pretty.Crux, term: swi.term_t) void {
    initFunctors();
    const temp = swi.PL_new_term_ref();
    const last = swi.PL_new_term_ref();
    const base = swi.PL_new_term_ref();
    const icky = swi.PL_new_term_ref();
    const rows = swi.PL_new_term_ref();

    _ = swi.PL_put_int64(last, @intCast(crux.last));
    _ = swi.PL_put_int64(base, @intCast(crux.base));
    _ = swi.PL_put_bool(icky, if (crux.icky) 1 else 0);
    _ = swi.PL_put_int64(rows, @intCast(crux.rows));

    _ = swi.PL_cons_functor(temp, crux_functor, last, base, icky, rows);
    _ = swi.PL_unify(term, temp);
}

// Helper: convert Cope to cope(node, crux)
fn copeToTerm(cope: pretty.Cope, term: swi.term_t) void {
    initFunctors();
    const temp = swi.PL_new_term_ref();
    const node = swi.PL_new_term_ref();
    const crux = swi.PL_new_term_ref();

    nodeToTerm(cope.node, node);
    cruxToTerm(cope.crux, crux);

    _ = swi.PL_cons_functor(temp, cope_functor, node, crux);
    _ = swi.PL_unify(term, temp);
}

// Convert individual field values to terms (for generic converter)
fn fieldToTerm(comptime T: type, value: T, term: swi.term_t) !void {
    const type_info = @typeInfo(T);

    switch (type_info) {
        .int => {
            _ = swi.PL_put_int64(term, @intCast(value));
        },
        .@"struct" => {
            // Check if it's a Node type
            if (T == pretty.Node) {
                nodeToTerm(value, term);
            } else if (T == pretty.Pair) {
                pairToTerm(value, term);
            } else {
                // Recursively handle nested structs
                try structToTerm(T, value, term);
            }
        },
        else => {
            return error.UnsupportedFieldType;
        },
    }
}

// open_trace(Path) - open binary trace file
fn pl_open_trace(t_path: swi.term_t) callconv(.c) swi.foreign_t {
    var path_ptr: [*c]u8 = undefined;
    var path_len: usize = 0;

    if (swi.PL_get_nchars(t_path, &path_len, @ptrCast(&path_ptr), swi.CVT_ATOM | swi.CVT_STRING) == 0) {
        return 0; // Failed to get path string
    }

    const path = path_ptr[0..path_len];

    // Close existing trace if open
    if (trace_file) |f| {
        f.close();
        trace_file = null;
    }

    // Open new trace
    trace_file = std.fs.cwd().openFile(path, .{}) catch {
        return 0; // Failed to open file
    };

    // Verify magic header
    var magic: [8]u8 = undefined;
    _ = trace_file.?.read(&magic) catch {
        trace_file.?.close();
        trace_file = null;
        return 0;
    };

    if (!std.mem.eql(u8, &magic, heap_binary.TRACE_MAGIC)) {
        trace_file.?.close();
        trace_file = null;
        return 0; // Invalid magic
    }

    return 1; // Success
}

// close_trace() - close binary trace file
fn pl_close_trace() callconv(.c) swi.foreign_t {
    if (trace_file) |f| {
        f.close();
        trace_file = null;
    }
    return 1;
}

// Helper: read integer from trace
fn readInt(comptime T: type) !T {
    if (trace_file == null) return error.NoTraceFile;
    var bytes: [@sizeOf(T)]u8 = undefined;
    const n = try trace_file.?.read(&bytes);
    if (n < @sizeOf(T)) return error.EndOfStream;
    return std.mem.readInt(T, &bytes, .little);
}

// next_event(Step, EventType) - read next event from trace
// EventType is one of: gc_start, gc_forward, heap_snapshot, gc_end
fn pl_next_event(t_step: swi.term_t, t_event_type: swi.term_t) callconv(.c) swi.foreign_t {
    if (trace_file == null) return 0;

    const event_type_byte = readInt(u8) catch {
        return 0; // End of file or error
    };
    const step = readInt(u64) catch {
        return 0;
    };

    // Unify step
    if (swi.PL_unify_integer(t_step, @intCast(step)) == 0) {
        return 0;
    }

    // Create atom for event type and unify
    const event_type = @as(heap_binary.EventType, @enumFromInt(event_type_byte));
    const event_name = switch (event_type) {
        .gc_start => "gc_start",
        .gc_forward => "gc_forward",
        .heap_snapshot => "heap_snapshot",
        .gc_end => "gc_end",
    };

    const atom = swi.PL_new_atom(event_name.ptr);
    if (swi.PL_unify_atom(t_event_type, atom) == 0) {
        return 0;
    }

    // Skip event data for now - we'll add detailed reading later
    switch (event_type) {
        .gc_start, .gc_end => {
            _ = readInt(u32) catch return 0; // heap_size
        },
        .gc_forward => {
            _ = readInt(u32) catch return 0; // old_node
            _ = readInt(u32) catch return 0; // new_node
        },
        .heap_snapshot => {
            // Read and skip all rack lengths
            inline for (0..9) |_| {
                _ = readInt(u32) catch return 0;
            }
            // Skip rack data - would need to implement full reading
            // For now just fail on heap_snapshot
            return 0;
        },
    }

    return 1; // Success
}

// gc_forward(Step, OldNode, NewNode) - read next gc_forward event
fn pl_gc_forward(t_step: swi.term_t, t_old: swi.term_t, t_new: swi.term_t) callconv(.c) swi.foreign_t {
    if (trace_file == null) return 0;

    // Keep reading until we find a gc_forward event
    while (true) {
        const event_type_byte = readInt(u8) catch return 0;
        const step = readInt(u64) catch return 0;
        const event_type = @as(heap_binary.EventType, @enumFromInt(event_type_byte));

        switch (event_type) {
            .gc_forward => {
                const old_bits = readInt(u32) catch return 0;
                const new_bits = readInt(u32) catch return 0;

                const old_node: pretty.Node = @bitCast(old_bits);
                const new_node: pretty.Node = @bitCast(new_bits);

                // Unify step and nodes
                _ = swi.PL_unify_integer(t_step, @intCast(step));
                nodeToTerm(old_node, t_old);
                nodeToTerm(new_node, t_new);

                return 1;
            },
            .gc_start, .gc_end => {
                _ = readInt(u32) catch return 0;
            },
            .heap_snapshot => {
                // Skip heap snapshot
                inline for (0..9) |_| {
                    _ = readInt(u32) catch return 0;
                }
                // Can't easily skip without reading all data, so just fail
                return 0;
            },
        }
    }
}

// test_node(NodeTerm) - test simple Node conversion
fn pl_test_node(t_node: swi.term_t) callconv(.c) swi.foreign_t {
    const test_node: pretty.Node = @bitCast(@as(u32, 0x12345678));
    nodeToTerm(test_node, t_node);
    return 1;
}

// test_pair(PairTerm) - demonstrate Pair struct conversion
fn pl_test_pair(t_pair: swi.term_t) callconv(.c) swi.foreign_t {
    const test_pair = pretty.Pair{
        .head = @bitCast(@as(u32, 0x12345678)),
        .tail = @bitCast(@as(u32, 0xABCDEF00)),
    };

    pairToTerm(test_pair, t_pair);
    return 1;
}

// node_tag(NodeRepr, Tag) - extract tag from Node representation
fn pl_node_tag(t_node_repr: swi.term_t, t_tag: swi.term_t) callconv(.c) swi.foreign_t {
    var repr: i64 = 0;
    if (swi.PL_get_int64(t_node_repr, &repr) == 0) return 0;

    const node: pretty.Node = @bitCast(@as(u32, @intCast(repr)));
    const tag_name = switch (node.tag) {
        .span => "span",
        .quad => "quad",
        .trip => "trip",
        .rune => "rune",
        .hcat => "hcat",
        .fork => "fork",
        .cons => "cons",
    };

    _ = swi.PL_unify_atom_chars(t_tag, tag_name.ptr);
    return 1;
}

// node_data(NodeRepr, Data) - extract 29-bit data field from Node representation
fn pl_node_data(t_node_repr: swi.term_t, t_data: swi.term_t) callconv(.c) swi.foreign_t {
    var repr: i64 = 0;
    if (swi.PL_get_int64(t_node_repr, &repr) == 0) return 0;

    const node: pretty.Node = @bitCast(@as(u32, @intCast(repr)));
    _ = swi.PL_unify_integer(t_data, @intCast(node.data));
    return 1;
}

// node_decode(NodeRepr, DecodedTerm) - decode Node based on tag
// Returns structured term based on the node type
fn pl_node_decode(t_node_repr: swi.term_t, t_decoded: swi.term_t) callconv(.c) swi.foreign_t {
    var repr: i64 = 0;
    if (swi.PL_get_int64(t_node_repr, &repr) == 0) return 0;

    const node: pretty.Node = @bitCast(@as(u32, @intCast(repr)));
    const look = node.look();

    initFunctors();
    const temp = swi.PL_new_term_ref();

    switch (look) {
        .span => |span| {
            const functor = swi.PL_new_functor(swi.PL_new_atom("span"), 3);
            const side_t = swi.PL_new_term_ref();
            const char_t = swi.PL_new_term_ref();
            const text_t = swi.PL_new_term_ref();

            const side_name: []const u8 = if (span.side == .lchr) "lchr" else "rchr";
            _ = swi.PL_put_atom_chars(side_t, side_name.ptr);
            _ = swi.PL_put_int64(char_t, @intCast(span.char));
            _ = swi.PL_put_int64(text_t, @intCast(span.text));
            _ = swi.PL_cons_functor(temp, functor, side_t, char_t, text_t);
        },
        .quad => |quad| {
            const functor = swi.PL_new_functor(swi.PL_new_atom("quad"), 4);
            const ch0_t = swi.PL_new_term_ref();
            const ch1_t = swi.PL_new_term_ref();
            const ch2_t = swi.PL_new_term_ref();
            const ch3_t = swi.PL_new_term_ref();
            _ = swi.PL_put_int64(ch0_t, @intCast(quad.ch0));
            _ = swi.PL_put_int64(ch1_t, @intCast(quad.ch1));
            _ = swi.PL_put_int64(ch2_t, @intCast(quad.ch2));
            _ = swi.PL_put_int64(ch3_t, @intCast(quad.ch3));
            _ = swi.PL_cons_functor(temp, functor, ch0_t, ch1_t, ch2_t, ch3_t);
        },
        .trip => |trip| {
            const functor = swi.PL_new_functor(swi.PL_new_atom("trip"), 4);
            const reps_t = swi.PL_new_term_ref();
            const byte0_t = swi.PL_new_term_ref();
            const byte1_t = swi.PL_new_term_ref();
            const byte2_t = swi.PL_new_term_ref();
            _ = swi.PL_put_int64(reps_t, @intCast(trip.reps));
            _ = swi.PL_put_int64(byte0_t, @intCast(trip.byte0));
            _ = swi.PL_put_int64(byte1_t, @intCast(trip.byte1));
            _ = swi.PL_put_int64(byte2_t, @intCast(trip.byte2));
            _ = swi.PL_cons_functor(temp, functor, reps_t, byte0_t, byte1_t, byte2_t);
        },
        .rune => |rune| {
            const functor = swi.PL_new_functor(swi.PL_new_atom("rune"), 2);
            const reps_t = swi.PL_new_term_ref();
            const code_t = swi.PL_new_term_ref();
            _ = swi.PL_put_int64(reps_t, @intCast(rune.reps));
            _ = swi.PL_put_int64(code_t, @intCast(rune.code));
            _ = swi.PL_cons_functor(temp, functor, reps_t, code_t);
        },
        .hcat, .cons, .fork => |oper| {
            const tag_name = switch (node.tag) {
                .hcat => "hcat",
                .cons => "cons",
                .fork => "fork",
                else => unreachable,
            };
            const functor = swi.PL_new_functor(swi.PL_new_atom(tag_name), 3);
            const frob_t = swi.PL_new_term_ref();
            const flip_t = swi.PL_new_term_ref();
            const item_t = swi.PL_new_term_ref();
            frobToTerm(oper.frob, frob_t);
            _ = swi.PL_put_int64(flip_t, @intCast(oper.flip));
            _ = swi.PL_put_int64(item_t, @intCast(oper.item));
            _ = swi.PL_cons_functor(temp, functor, frob_t, flip_t, item_t);
        },
    }

    _ = swi.PL_unify(t_decoded, temp);
    return 1;
}

// Helper: parse Prolog term to Crux
fn termToCrux(term: swi.term_t) !pretty.Crux {
    // crux(Last, Base, Icky, Rows) - Icky can be false/true (atoms) or 0/1 (ints)
    var last: i64 = 0;
    var base: i64 = 0;
    var rows: i64 = 0;

    const arg1 = swi.PL_new_term_ref();
    const arg2 = swi.PL_new_term_ref();
    const arg3 = swi.PL_new_term_ref();
    const arg4 = swi.PL_new_term_ref();

    if (swi.PL_get_arg(1, term, arg1) == 0) return error.BadCrux;
    if (swi.PL_get_arg(2, term, arg2) == 0) return error.BadCrux;
    if (swi.PL_get_arg(3, term, arg3) == 0) return error.BadCrux;
    if (swi.PL_get_arg(4, term, arg4) == 0) return error.BadCrux;

    if (swi.PL_get_int64(arg1, &last) == 0) return error.BadCrux;
    if (swi.PL_get_int64(arg2, &base) == 0) return error.BadCrux;
    if (swi.PL_get_int64(arg4, &rows) == 0) return error.BadCrux;

    // Parse icky - can be boolean atom or integer
    var icky: bool = false;
    var icky_int: i64 = 0;
    if (swi.PL_get_int64(arg3, &icky_int) != 0) {
        // It's an integer
        icky = icky_int != 0;
    } else {
        // Try as boolean atom
        var icky_atom: swi.atom_t = 0;
        if (swi.PL_get_atom(arg3, &icky_atom) == 0) return error.BadCrux;
        const icky_chars = swi.PL_atom_chars(icky_atom);
        const icky_str = std.mem.span(icky_chars);
        if (std.mem.eql(u8, icky_str, "true")) {
            icky = true;
        } else if (std.mem.eql(u8, icky_str, "false")) {
            icky = false;
        } else {
            return error.BadCrux;
        }
    }

    return pretty.Crux{
        .last = @intCast(last),
        .base = @intCast(base),
        .icky = icky,
        .rows = @intCast(rows),
    };
}

// Helper: parse Prolog term to Deck
fn termToDeck(term: swi.term_t) !pretty.Deck {
    // deck(Flip, Cope, Item)
    var flip: i64 = 0;
    var cope: i64 = 0;
    var item: i64 = 0;

    const arg1 = swi.PL_new_term_ref();
    const arg2 = swi.PL_new_term_ref();
    const arg3 = swi.PL_new_term_ref();

    if (swi.PL_get_arg(1, term, arg1) == 0) return error.BadDeck;
    if (swi.PL_get_arg(2, term, arg2) == 0) return error.BadDeck;
    if (swi.PL_get_arg(3, term, arg3) == 0) return error.BadDeck;

    if (swi.PL_get_int64(arg1, &flip) == 0) return error.BadDeck;
    if (swi.PL_get_int64(arg2, &cope) == 0) return error.BadDeck;
    if (swi.PL_get_int64(arg3, &item) == 0) return error.BadDeck;

    return pretty.Deck{
        .flip = @intCast(flip),
        .cope = @intCast(cope),
        .item = @intCast(item),
    };
}

// Helper: parse Prolog term to Kont
fn termToKont(term: swi.term_t) !pretty.Kont {
    // kont(Kind, Flip, Item) where Kind is an atom
    var kind_atom: swi.atom_t = 0;
    var flip: i64 = 0;
    var item: i64 = 0;

    const arg1 = swi.PL_new_term_ref();
    const arg2 = swi.PL_new_term_ref();
    const arg3 = swi.PL_new_term_ref();

    if (swi.PL_get_arg(1, term, arg1) == 0) return error.BadKont;
    if (swi.PL_get_arg(2, term, arg2) == 0) return error.BadKont;
    if (swi.PL_get_arg(3, term, arg3) == 0) return error.BadKont;

    if (swi.PL_get_atom(arg1, &kind_atom) == 0) return error.BadKont;
    if (swi.PL_get_int64(arg2, &flip) == 0) return error.BadKont;
    if (swi.PL_get_int64(arg3, &item) == 0) return error.BadKont;

    const kind_chars = swi.PL_atom_chars(kind_atom);
    const kind_str = std.mem.span(kind_chars);

    const kind: pretty.Kont.Kind = if (std.mem.eql(u8, kind_str, "none"))
        .none
    else if (std.mem.eql(u8, kind_str, "head"))
        .head
    else if (std.mem.eql(u8, kind_str, "tail"))
        .tail
    else if (std.mem.eql(u8, kind_str, "iter"))
        .iter
    else if (std.mem.eql(u8, kind_str, "fork"))
        .fork
    else
        return error.BadKont;

    return pretty.Kont{
        .kind = kind,
        .flip = @intCast(flip),
        .item = @intCast(item),
    };
}

// Helper: parse Prolog term to Exec
fn termToExec(term: swi.term_t) !pretty.Exec {
    // exec(node(NodeRepr), Tick, Kont)
    const arg1 = swi.PL_new_term_ref();
    const arg2 = swi.PL_new_term_ref();
    const arg3 = swi.PL_new_term_ref();

    if (swi.PL_get_arg(1, term, arg1) == 0) return error.BadExec;
    if (swi.PL_get_arg(2, term, arg2) == 0) return error.BadExec;
    if (swi.PL_get_arg(3, term, arg3) == 0) return error.BadExec;

    // Parse node(NodeRepr)
    const node_arg = swi.PL_new_term_ref();
    if (swi.PL_get_arg(1, arg1, node_arg) == 0) return error.BadExec;
    var node_repr: i64 = 0;
    if (swi.PL_get_int64(node_arg, &node_repr) == 0) return error.BadExec;
    const node: pretty.Node = @bitCast(@as(u32, @intCast(node_repr)));

    // Parse tick union - check if it's eval(...) or give(...)
    var tick_name: swi.atom_t = 0;
    var tick_arity: c_int = 0;
    if (swi.PL_get_name_arity(arg2, &tick_name, &tick_arity) == 0) return error.BadExec;

    const tick_chars = swi.PL_atom_chars(tick_name);
    const tick_str = std.mem.span(tick_chars);

    const kont = try termToKont(arg3);

    if (std.mem.eql(u8, tick_str, "eval")) {
        const crux_term = swi.PL_new_term_ref();
        if (swi.PL_get_arg(1, arg2, crux_term) == 0) return error.BadExec;
        const crux = try termToCrux(crux_term);
        return pretty.Exec{
            .node = node,
            .tick = .{ .eval = crux },
            .then = kont,
        };
    } else if (std.mem.eql(u8, tick_str, "give")) {
        const deck_term = swi.PL_new_term_ref();
        if (swi.PL_get_arg(1, arg2, deck_term) == 0) return error.BadExec;
        const deck = try termToDeck(deck_term);
        return pretty.Exec{
            .node = node,
            .tick = .{ .give = deck },
            .then = kont,
        };
    } else {
        return error.BadExec;
    }
}

// Helper: convert Exec to Prolog term exec(node, tick, then)
fn execToTerm(exec: pretty.Exec, term: swi.term_t) void {
    initFunctors();
    const exec_functor = swi.PL_new_functor(swi.PL_new_atom("exec"), 3);
    const temp = swi.PL_new_term_ref();
    const node_t = swi.PL_new_term_ref();
    const tick_t = swi.PL_new_term_ref();
    const then_t = swi.PL_new_term_ref();

    nodeToTerm(exec.node, node_t);

    // Convert tick union
    switch (exec.tick) {
        .eval => |crux| {
            const eval_functor = swi.PL_new_functor(swi.PL_new_atom("eval"), 1);
            const crux_t = swi.PL_new_term_ref();
            cruxToTerm(crux, crux_t);
            _ = swi.PL_cons_functor(tick_t, eval_functor, crux_t);
        },
        .give => |deck| {
            const give_functor = swi.PL_new_functor(swi.PL_new_atom("give"), 1);
            const deck_t = swi.PL_new_term_ref();
            deckToTerm(deck, deck_t);
            _ = swi.PL_cons_functor(tick_t, give_functor, deck_t);
        },
    }

    kontToTerm(exec.then, then_t);

    _ = swi.PL_cons_functor(temp, exec_functor, node_t, tick_t, then_t);
    _ = swi.PL_unify(term, temp);
}

// ============================================================================
// Node Builder DSL - Build Zig nodes from Prolog terms
// ============================================================================

// init_builder() - Initialize the global build tree
fn pl_init_builder() callconv(.c) swi.foreign_t {
    // Clean up existing tree if any
    if (build_tree) |tree| {
        tree.deinit();
        build_gpa.allocator().destroy(tree);
    }

    const allocator = build_gpa.allocator();
    const tree = allocator.create(pretty.Tree) catch return 0;
    tree.* = pretty.Tree.init(allocator);
    build_tree = tree;

    return 1;
}

// build_text(String, -NodeRepr) - Create text node
fn pl_build_text(t_string: swi.term_t, t_node: swi.term_t) callconv(.c) swi.foreign_t {
    if (build_tree == null) return 0;

    var chars: [*c]u8 = undefined;
    if (swi.PL_get_atom_chars(t_string, &chars) == 0) return 0;

    const str = std.mem.span(chars);
    const node = build_tree.?.text(str) catch return 0;

    const repr: i64 = @intCast(node.repr());
    _ = swi.PL_unify_int64(t_node, repr);
    return 1;
}

// build_hcat(NodeA, NodeB, -NodeRepr) - Create hcat node
fn pl_build_hcat(t_a: swi.term_t, t_b: swi.term_t, t_node: swi.term_t) callconv(.c) swi.foreign_t {
    if (build_tree == null) return 0;

    var a_repr: i64 = 0;
    var b_repr: i64 = 0;
    if (swi.PL_get_int64(t_a, &a_repr) == 0) return 0;
    if (swi.PL_get_int64(t_b, &b_repr) == 0) return 0;

    const node_a: pretty.Node = @bitCast(@as(u32, @intCast(a_repr)));
    const node_b: pretty.Node = @bitCast(@as(u32, @intCast(b_repr)));

    const node = build_tree.?.hcat(.{}, node_a, node_b) catch return 0;

    const repr: i64 = @intCast(node.repr());
    _ = swi.PL_unify_int64(t_node, repr);
    return 1;
}

// build_fork(NodeA, NodeB, -NodeRepr) - Create fork node
fn pl_build_fork(t_a: swi.term_t, t_b: swi.term_t, t_node: swi.term_t) callconv(.c) swi.foreign_t {
    if (build_tree == null) return 0;

    var a_repr: i64 = 0;
    var b_repr: i64 = 0;
    if (swi.PL_get_int64(t_a, &a_repr) == 0) return 0;
    if (swi.PL_get_int64(t_b, &b_repr) == 0) return 0;

    const node_a: pretty.Node = @bitCast(@as(u32, @intCast(a_repr)));
    const node_b: pretty.Node = @bitCast(@as(u32, @intCast(b_repr)));

    const node = build_tree.?.fork(node_a, node_b) catch return 0;

    const repr: i64 = @intCast(node.repr());
    _ = swi.PL_unify_int64(t_node, repr);
    return 1;
}

// build_plus(NodeA, NodeB, -NodeRepr) - Create plus/cons node
fn pl_build_plus(t_a: swi.term_t, t_b: swi.term_t, t_node: swi.term_t) callconv(.c) swi.foreign_t {
    if (build_tree == null) return 0;

    var a_repr: i64 = 0;
    var b_repr: i64 = 0;
    if (swi.PL_get_int64(t_a, &a_repr) == 0) return 0;
    if (swi.PL_get_int64(t_b, &b_repr) == 0) return 0;

    const node_a: pretty.Node = @bitCast(@as(u32, @intCast(a_repr)));
    const node_b: pretty.Node = @bitCast(@as(u32, @intCast(b_repr)));

    const node = build_tree.?.plus(node_a, node_b) catch return 0;

    const repr: i64 = @intCast(node.repr());
    _ = swi.PL_unify_int64(t_node, repr);
    return 1;
}

// build_nest(Indent, NodeIn, -NodeRepr) - Create nested node
fn pl_build_nest(t_indent: swi.term_t, t_in: swi.term_t, t_node: swi.term_t) callconv(.c) swi.foreign_t {
    if (build_tree == null) return 0;

    var indent: i64 = 0;
    var in_repr: i64 = 0;
    if (swi.PL_get_int64(t_indent, &indent) == 0) return 0;
    if (swi.PL_get_int64(t_in, &in_repr) == 0) return 0;

    const node_in: pretty.Node = @bitCast(@as(u32, @intCast(in_repr)));
    const node = build_tree.?.nest(@intCast(indent), node_in) catch return 0;

    const repr: i64 = @intCast(node.repr());
    _ = swi.PL_unify_int64(t_node, repr);
    return 1;
}

// build_warp(NodeIn, -NodeRepr) - Create warped (aligned) node
fn pl_build_warp(t_in: swi.term_t, t_node: swi.term_t) callconv(.c) swi.foreign_t {
    if (build_tree == null) return 0;

    var in_repr: i64 = 0;
    if (swi.PL_get_int64(t_in, &in_repr) == 0) return 0;

    const node_in: pretty.Node = @bitCast(@as(u32, @intCast(in_repr)));
    const node = build_tree.?.warp(node_in) catch return 0;

    const repr: i64 = @intCast(node.repr());
    _ = swi.PL_unify_int64(t_node, repr);
    return 1;
}

// node_nl(-NodeRepr) - Get the newline node
fn pl_node_nl(t_node: swi.term_t) callconv(.c) swi.foreign_t {
    const repr: i64 = @intCast(pretty.Node.nl.repr());
    _ = swi.PL_unify_int64(t_node, repr);
    return 1;
}

// ============================================================================
// Loop Execution
// ============================================================================

// init_loop(NodeRepr, Width) - initialize Loop state for step-by-step execution
// IMPORTANT: Uses the build_tree created by init_builder, not a fresh tree!
fn pl_init_loop(t_node_repr: swi.term_t, t_width: swi.term_t) callconv(.c) swi.foreign_t {
    // Must have a build_tree with nodes
    if (build_tree == null) return 0;

    // Clean up any existing loop state
    if (loop_state) |loop| {
        loop.deinit();
        build_gpa.allocator().destroy(loop); // Use same allocator that created it!
        loop_state = null;
    }
    // Don't clean up loop_tree - we'll reuse build_tree

    // Get parameters
    var node_repr: i64 = 0;
    if (swi.PL_get_int64(t_node_repr, &node_repr) == 0) return 0;

    var width: i64 = 0;
    if (swi.PL_get_int64(t_width, &width) == 0) return 0;

    const allocator = build_gpa.allocator();

    // Use build_tree as loop_tree
    const tree = build_tree.?;
    loop_tree = tree;

    // Create Loop
    const node: pretty.Node = @bitCast(@as(u32, @intCast(node_repr)));
    const cost = pretty.F2.init(@intCast(width));

    const loop = allocator.create(pretty.Loop) catch return 0;
    loop.* = pretty.Loop{
        .tree = tree,
        .heap = &tree.heap,
        .cost = cost,
        .memo = .init(allocator),
        .root = node,
        .exec = .{
            .node = node,
            .tick = .{ .eval = .{} },
        },
    };
    loop_state = loop;

    return 1;
}

// make_loop(+NodeRepr, +Width, -LoopBlob) - Create a Loop and return it as a BLOB
fn pl_make_loop(t_node_repr: swi.term_t, t_width: swi.term_t, t_loop_blob: swi.term_t) callconv(.c) swi.foreign_t {
    // Must have a build_tree with nodes
    if (build_tree == null) return 0;

    // Get parameters
    var node_repr: i64 = 0;
    if (swi.PL_get_int64(t_node_repr, &node_repr) == 0) return 0;

    var width: i64 = 0;
    if (swi.PL_get_int64(t_width, &width) == 0) return 0;

    const allocator = build_gpa.allocator();
    const tree = build_tree.?;

    // Create Loop
    const node: pretty.Node = @bitCast(@as(u32, @intCast(node_repr)));
    const cost = pretty.F2.init(@intCast(width));

    const loop = allocator.create(pretty.Loop) catch return 0;
    loop.* = pretty.Loop{
        .tree = tree,
        .heap = &tree.heap,
        .cost = cost,
        .memo = .init(allocator),
        .root = node,
        .exec = .{
            .node = node,
            .then = .none,
            .tick = .{ .eval = .{} },
        },
    };

    // Create BLOB containing the loop pointer
    _ = swi.PL_unify_blob(t_loop_blob, loop, @sizeOf(*pretty.Loop), &loop_blob_type);

    return 1;
}

// step(+LoopBlob, +ExecIn, -ExecOut) - Pure binary relation with explicit state
fn pl_step_blob(t_loop_blob: swi.term_t, t_exec_in: swi.term_t, t_exec_out: swi.term_t) callconv(.c) swi.foreign_t {
    // Extract loop from blob
    var atom: swi.atom_t = 0;
    if (swi.PL_get_atom(t_loop_blob, &atom) == 0) {
        std.debug.print("step/3: Not an atom\n", .{});
        return 0;
    }

    var len: usize = 0;
    var type_ptr: [*c]swi.PL_blob_t = null;
    const ptr = swi.PL_blob_data(atom, &len, &type_ptr) orelse {
        std.debug.print("step/3: No blob data\n", .{});
        return 0;
    };

    const loop: *pretty.Loop = @ptrCast(@alignCast(ptr));

    // Parse input exec from Prolog term
    loop.exec = termToExec(t_exec_in) catch return 0;

    // Perform one CEK machine step
    loop.step() catch return 0;

    // Convert result to Prolog term
    execToTerm(loop.exec, t_exec_out);
    return 1;
}

// OLD API (deprecated): step(+ExecIn, -ExecOut) - uses global loop_state
fn pl_step(t_exec_in: swi.term_t, t_exec_out: swi.term_t) callconv(.c) swi.foreign_t {
    if (loop_state == null) {
        std.debug.print("step/2: No loop initialized\n", .{});
        return 0;
    }

    // Parse input exec from Prolog term
    var exec = termToExec(t_exec_in) catch |err| {
        std.debug.print("step/2: Failed to parse exec term: {}\n", .{err});
        return 0;
    };

    std.debug.print("step/2: Parsed exec successfully\n", .{});

    // Perform one CEK machine step
    loop_state.?.step(&exec, false) catch |err| {
        std.debug.print("step/2: Step failed: {}\n", .{err});
        return 0;
    };

    std.debug.print("step/2: Step succeeded\n", .{});

    // Convert result to Prolog term
    execToTerm(exec, t_exec_out);
    return 1;
}

// step_once(ExecIn, ExecOut) - perform one step of the pretty printer exploration
fn pl_step_once(t_exec_in: swi.term_t, t_exec_out: swi.term_t) callconv(.c) swi.foreign_t {
    _ = t_exec_in; // Currently using global state, not input parameter

    if (loop_state == null) return 0; // No loop initialized

    const loop = loop_state.?;

    const exec = current_exec.?;

    // Perform one step
    loop.step() catch {
        return 0;
    };

    // Check if this exec is complete (giving with no continuation)
    const is_complete = switch (exec.tick) {
        .give => |deck| exec.then.kind == .none and deck.cope == 0,
        else => false,
    };

    // If complete, clear current_exec so next call pops from pile
    if (is_complete) {
        current_exec = null;
    } else {
        current_exec = exec;
    }

    // Convert to Prolog term
    execToTerm(exec, t_exec_out);
    return 1;
}

// is_complete(Exec) - check if execution is complete
fn pl_is_complete(t_exec: swi.term_t) callconv(.c) swi.foreign_t {
    _ = t_exec; // Currently using global state, not input parameter

    if (current_exec == null) return 0;

    const exec = current_exec.?;

    // Complete when we're giving a result and have no continuation
    const complete = switch (exec.tick) {
        .give => exec.then.kind == .none,
        else => false,
    };

    return if (complete) 1 else 0;
}

// Installation function - called when library is loaded
// Named 'install' to match SWI-Prolog convention
export fn install() callconv(.c) void {
    // Register BLOB types
    swi.PL_register_blob_type(&loop_blob_type);

    // Trace file operations
    _ = swi.PL_register_foreign("open_trace", 1, @ptrCast(&pl_open_trace), 0);
    _ = swi.PL_register_foreign("close_trace", 0, @ptrCast(&pl_close_trace), 0);
    _ = swi.PL_register_foreign("next_event", 2, @ptrCast(&pl_next_event), 0);
    _ = swi.PL_register_foreign("gc_forward", 3, @ptrCast(&pl_gc_forward), 0);

    // Node decoding predicates
    _ = swi.PL_register_foreign("node_tag", 2, @ptrCast(&pl_node_tag), 0);
    _ = swi.PL_register_foreign("node_data", 2, @ptrCast(&pl_node_data), 0);
    _ = swi.PL_register_foreign("node_decode", 2, @ptrCast(&pl_node_decode), 0);

    // Node builder DSL
    _ = swi.PL_register_foreign("init_builder", 0, @ptrCast(&pl_init_builder), 0);
    _ = swi.PL_register_foreign("build_text", 2, @ptrCast(&pl_build_text), 0);
    _ = swi.PL_register_foreign("build_hcat", 3, @ptrCast(&pl_build_hcat), 0);
    _ = swi.PL_register_foreign("build_fork", 3, @ptrCast(&pl_build_fork), 0);
    _ = swi.PL_register_foreign("build_plus", 3, @ptrCast(&pl_build_plus), 0);
    _ = swi.PL_register_foreign("build_nest", 3, @ptrCast(&pl_build_nest), 0);
    _ = swi.PL_register_foreign("build_warp", 2, @ptrCast(&pl_build_warp), 0);
    _ = swi.PL_register_foreign("node_nl", 1, @ptrCast(&pl_node_nl), 0);

    // Step-by-step execution (old global state API - deprecated)
    _ = swi.PL_register_foreign("init_loop", 2, @ptrCast(&pl_init_loop), 0);
    _ = swi.PL_register_foreign("step_once", 2, @ptrCast(&pl_step_once), 0);
    _ = swi.PL_register_foreign("is_complete", 1, @ptrCast(&pl_is_complete), 0);

    // New BLOB-based API with explicit state
    _ = swi.PL_register_foreign("make_loop", 3, @ptrCast(&pl_make_loop), 0); // make_loop(Node, Width, -Loop)
    _ = swi.PL_register_foreign("step", 3, @ptrCast(&pl_step_blob), 0); // step(+Loop, +ExecIn, -ExecOut)

    // Test predicates
    _ = swi.PL_register_foreign("test_node", 1, @ptrCast(&pl_test_node), 0);
    _ = swi.PL_register_foreign("test_pair", 1, @ptrCast(&pl_test_pair), 0);
}
