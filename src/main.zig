const std = @import("std");
const builtin = @import("builtin");

const content = @embedFile("sl.json");

const is_windows = builtin.os.tag == .windows;

const w32 = if (is_windows) struct {
    const WINAPI = std.os.windows.WINAPI;
    const DWORD = std.os.windows.DWORD;
    const ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;
    const STD_ERROR_HANDLE = @bitCast(DWORD, @as(i32, -12));
    extern "kernel32" fn GetStdHandle(id: DWORD) callconv(WINAPI) ?*anyopaque;
    extern "kernel32" fn GetConsoleMode(console: ?*anyopaque, out_mode: *DWORD) callconv(WINAPI) u32;
    extern "kernel32" fn SetConsoleMode(console: ?*anyopaque, mode: DWORD) callconv(WINAPI) u32;
} else undefined;

pub fn main() anyerror!void {
    const handle = if (is_windows) w32.GetStdHandle(w32.STD_ERROR_HANDLE) else @as(i32, 0);
    var mode = if (is_windows) @as(w32.DWORD, 0) else @as(i32, 0);

    if (builtin.os.tag == .windows) {
        if (w32.GetConsoleMode(handle, &mode) != 0) {
            mode |= w32.ENABLE_VIRTUAL_TERMINAL_PROCESSING;
            mode = w32.SetConsoleMode(handle, mode);
        }
    }

    var allocator = std.heap.page_allocator;
    var p = std.json.Parser.init(allocator, false);
    defer p.deinit();
    var data = (p.parse(content) catch unreachable).root;

    var i: u32 = 0;
    var j: u32 = 0;
    var parts: [3][]std.json.Value = undefined;
    parts[0] = data.Array.items[0].Array.items;
    parts[1] = data.Array.items[1].Array.items;
    parts[2] = data.Array.items[2].Array.items;
    var writer = std.io.getStdOut().writer();
    while (i < 170) : (i += 1) {
        try std.io.getStdOut().writer().print("{s}\n", .{"\x1b[2J\x1b[1;1H"});
        for (parts) |part| {
            for (part[i % part.len].Array.items) |line| {
                var bytes = std.ArrayList(u8).init(allocator);
                defer bytes.deinit();
                j = 0;
                if (i < 80) {
                    while (j < 80 - i) : (j += 1) {
                        try bytes.append(' ');
                    }
                }
                try bytes.writer().writeAll(line.String);
                var b = bytes.items;
                if (i >= 80) {
                    if (b.len > (i - 80)) {
                        b = b[(i - 80)..];
                    } else {
                        b = "";
                    }
                }
                if (b.len > 80) {
                    b = b[0..80];
                }
                try writer.writeAll(b);
                try writer.writeByte('\n');
            }
        }
        std.time.sleep(2e7);
    }

    if (builtin.os.tag == .windows) {
        _ = w32.SetConsoleMode(handle, mode);
    } else {
        _ = handle;
        _ = mode;
    }
}
