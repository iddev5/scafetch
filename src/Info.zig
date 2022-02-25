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

    try writer.print("- repository: {s}\n", .{info.repository});
    try writer.print("- license: {s}\n", .{info.license});
    try writer.print("- default branch: {s}\n", .{info.branch});
    try writer.print("- created: {s}\n", .{info.created[0..10]});
    // TODO: print in form "x hours ago" for below
    try writer.print("- modified: {s}\n", .{info.modified[0..10]});
    try writer.print("- language: {s}\n", .{info.language});
    try writer.print("- size: {} KB\n", .{info.size});
    try writer.print("- stars: {}\n", .{info.stars});
    try writer.print("- watches: {}\n", .{info.watches});
    try writer.print("- forks: {}\n", .{info.forks});
}
