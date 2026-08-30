const std = @import("std");
const zoot = @import("zoot");

const allocator = std.heap.wasm_allocator;
var last_error: u32 = 0;

/// Allocate bytes in the module's exported memory. The host writes CBOR here.
export fn zoot_alloc(len: u32) u32 {
    const memory = allocator.alloc(u8, len) catch {
        last_error = 2;
        return 0;
    };
    return @intFromPtr(memory.ptr);
}

/// Free a buffer returned by zoot_alloc or zoot_format_cbor.
export fn zoot_free(address: u32, len: u32) void {
    if (address == 0) return;
    const ptr: [*]u8 = @ptrFromInt(address);
    allocator.free(ptr[0..len]);
}

/// Format one CBOR value as JSON at width 80.
/// The low 32 bits of the result are the output pointer and the high 32 bits
/// are its byte length. Zero indicates failure; call zoot_last_error().
export fn zoot_format_cbor(address: u32, len: u32) u64 {
    last_error = 0;
    const ptr: [*]const u8 = @ptrFromInt(address);
    return format(ptr[0..len]) catch |err| {
        last_error = if (err == error.OutOfMemory) 2 else 1;
        return 0;
    };
}

export fn zoot_last_error() u32 {
    return last_error;
}

fn format(input: []const u8) !u64 {
    const owned = try zoot.CborFormat.format(allocator, input, 80);
    if (owned.len > std.math.maxInt(u32)) {
        allocator.free(owned);
        return error.OutputTooLarge;
    }
    return (@as(u64, @intCast(owned.len)) << 32) | @as(u64, @intFromPtr(owned.ptr));
}
