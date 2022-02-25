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

pub fn TtyColor(comptime WriterType: type) type {
    return struct {
        writer: WriterType,

        const Self = @This();

        pub fn init(writer: WriterType) Self {
            return .{
                .writer = writer,
            };
        }

        pub fn setColor(self: *const Self, color: Color) !void {
            const code = self.getCode(color);
            try self.setColorCode(code);
        }

        pub fn setColorCode(self: *const Self, code: []const u8) !void {
            if (builtin.os.tag == .windows) {} else {
                try self.writer.print("\x1b[{s}m", .{code});
            }
        }

        pub fn setBold(self: *const Self) !void {
            try self.setColorCode("1");
        }

        pub fn reset(self: *const Self) !void {
            try self.setColorCode("0");
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
}
