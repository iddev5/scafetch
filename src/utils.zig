const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

pub fn requestGet(allocator: Allocator, url: []const u8) ![]const u8 {
    const uri = try std.Uri.parse(url);

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var header_buf: [4096]u8 = undefined;

    var req = try client.open(.GET, uri, .{ .server_header_buffer = &header_buf });
    defer req.deinit();

    try req.send();
    try req.finish();
    try req.wait();

    const reader = req.reader();
    const body = try reader.readAllAlloc(allocator, std.math.maxInt(usize));
    errdefer allocator.free(body);

    return body;
}

pub const Color = enum {
    red,
    green,
    yellow,
    blue,
    purple,
};

const windows = std.os.windows;

pub const ConsoleStyle = struct {
    f: std.fs.File,
    attrs: AttrType(),

    fn AttrType() type {
        return switch (builtin.os.tag) {
            .windows => windows.WORD,
            else => void,
        };
    }

    const Self = @This();
    pub fn init(f: std.fs.File) Self {
        const attrs: AttrType() = blk: {
            switch (builtin.os.tag) {
                .windows => {
                    var info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
                    _ = windows.kernel32.GetConsoleScreenBufferInfo(f.handle, &info);
                    _ = windows.kernel32.SetConsoleOutputCP(65001);
                    break :blk info.wAttributes;
                },
                else => break :blk {},
            }
        };
        return .{
            .f = f,
            .attrs = attrs,
        };
    }

    pub fn setColor(self: *const Self, color: Color) !void {
        if (builtin.os.tag == .windows) {
            const col: u16 = switch (color) {
                .red => windows.FOREGROUND_RED,
                .green => windows.FOREGROUND_GREEN,
                .blue => windows.FOREGROUND_BLUE,
                .yellow => windows.FOREGROUND_RED | windows.FOREGROUND_GREEN,
                .purple => windows.FOREGROUND_RED | windows.FOREGROUND_BLUE,
            };

            try self.setAttrWin(col);
        } else {
            const code = switch (color) {
                .red => "31;1",
                .green => "32;1",
                .yellow => "33;1",
                .blue => "34;1",
                .purple => "35;1",
            };

            try self.writeCodeAscii(code);
        }
    }

    pub fn setBold(self: *const Self) !void {
        if (builtin.os.tag == .windows) {
            try self.setAttrWin(windows.FOREGROUND_INTENSITY);
        } else {
            try self.writeCodeAscii("1");
        }
    }

    pub fn reset(self: *const Self) !void {
        if (builtin.os.tag == .windows) {
            try self.setAttrWin(self.attrs);
        } else {
            try self.writeCodeAscii("0");
        }
    }

    fn setAttrWin(self: *const Self, attr: windows.WORD) !void {
        try windows.SetConsoleTextAttribute(self.f.handle, attr);
    }

    fn writeCodeAscii(self: *const Self, code: []const u8) !void {
        try self.f.writer().print("\x1b[{s}m", .{code});
    }
};
