const std = @import("std");
const Allocator = std.mem.Allocator;
const utils = @import("utils.zig");
const TtyColor = utils.TtyColor;

name: []const u8,
is_private: bool,
is_fork: bool,
is_archived: bool,
is_template: bool,
description: []const u8,
repository: []const u8,
language: []const u8,
size: u32,
stars: u32,
watches: u32,
forks: u32,
license: []const u8,
created: []const u8,
modified: []const u8,
branch: []const u8,

const Info = @This();
pub fn free(self: *Info, allocator: Allocator) void {
    allocator.free(self.name);
    allocator.free(self.description);
    allocator.free(self.repository);
    allocator.free(self.language);
    allocator.free(self.license);
    allocator.free(self.created);
    allocator.free(self.modified);
    allocator.free(self.branch);
}

pub fn print(info: *Info, writer: anytype) !void {
    const color = TtyColor(@TypeOf(writer)).init(writer);
    {
        try color.setColor(.red);

        try writer.print("  {s} ", .{info.name});
        if (info.is_fork) try writer.writeAll("🔗 ");
        if (info.is_private) try writer.writeAll("🔒 ");
        if (info.is_template) try writer.writeAll("🗒; ");
        if (info.is_archived) try writer.writeAll("📦 ");
        try writer.writeByte('\n');

        try color.setColor(.reset);
    }
    {
        var x: usize = 0;
        while (x < info.description.len) {
            const end = blk: {
                const amount = 60;
                if (x + amount >= info.description.len) {
                    break :blk info.description.len - x;
                } else {
                    break :blk amount;
                }
            };

            const str = std.mem.trimLeft(u8, info.description[x .. x + end], " ");
            try writer.print("{s}\n", .{str});
            x += end;
        }
        try writer.writeByte('\n');
    }

    const fields = .{
        "repository",
        "license",
        "branch",
        "created",
        "modified",
        "language",
        "size",
        "stars",
        "watches",
        "forks",
    };
    inline for (fields) |f| {
        const info_fields = std.meta.fields(Info);
        const field_id: usize = std.meta.fieldIndex(Info, f).?;
        const field = info_fields[field_id];

        try writer.writeByte('-');

        try color.setColor(.red);
        try writer.print(" {s}", .{field.name});
        try color.setColor(.reset);

        if (field.field_type == []const u8) {
            try writer.print(": {s}\n", .{@field(info, field.name)});
        } else {
            try writer.print(": {}\n", .{@field(info, field.name)});
        }
    }
}
