const builtin = @import("builtin");

pub fn TtyColor(comptime WriterType: type) type {
    return struct {
        writer: WriterType,

        pub const Color = enum {
            reset,
            black,
            red,
            green,
            yellow,
            blue,
            purple,
            white,
        };

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

        fn getCode(_: *const Self, color: Color) []const u8 {
            return switch (color) {
                .reset => "0",
                .black => "30;1",
                .red => "31;1",
                .green => "32;1",
                .yellow => "33;1",
                .blue => "34;1",
                .purple => "35;1",
                .white => "37;1",
            };
        }
    };
}
