const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
const zfetch = @import("zfetch");

pub fn requestGet(allocator: Allocator, url: []const u8) ![]const u8 {
    var headers = zfetch.Headers.init(allocator);
    defer headers.deinit();

    try headers.appendValue("Accept", "application/json");

    var req = try zfetch.Request.init(allocator, url, null);
    defer req.deinit();

    try req.do(.GET, headers, null);
    if (req.status.code != 200) {
        std.log.err("request return status code: {}: {s}\n", .{ req.status.code, req.status.reason });
        std.process.exit(1);
    }

    const reader = req.reader();

    var buf: [1024]u8 = undefined;
    var source = std.ArrayList(u8).init(allocator);
    defer source.deinit();

    while (true) {
        const read = try reader.read(&buf);
        if (read == 0) break;

        try source.appendSlice(buf[0..read]);
    }

    return source.toOwnedSlice();
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

            _ = try windows.SetConsoleTextAttribute(self.f.handle, col);
        } else {
            const code = self.getCode(color);
            try self.setColorCode(code);
        }
    }

    pub fn setColorCode(self: *const Self, code: []const u8) !void {
        try self.f.writer().print("\x1b[{s}m", .{code});
    }

    pub fn setBold(self: *const Self) !void {
        if (builtin.os.tag == .windows) {
            try windows.SetConsoleTextAttribute(self.f.handle, windows.FOREGROUND_INTENSITY);
        } else {
            try self.setColorCode("1");
        }
    }

    pub fn reset(self: *const Self) !void {
        if (builtin.os.tag == .windows) {
            try windows.SetConsoleTextAttribute(self.f.handle, self.attrs);
        } else {
            try self.setColorCode("0");
        }
    }

    fn getCode(_: *const Self, color: Color) []const u8 {
        return switch (color) {
            .red => "31;1",
            .green => "32;1",
            .yellow => "33;1",
            .blue => "34;1",
            .purple => "35;1",
        };
    }
};
