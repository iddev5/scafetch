const std = @import("std");
const Allocator = std.mem.Allocator;
const utils = @import("utils.zig");
const ConsoleStyle = utils.ConsoleStyle;

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

pub fn print(info: *Info, file: std.fs.File) !void {
    var rand_engine = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
    const random = rand_engine.random();
    const choice = random.enumValue(utils.Color);

    const writer = file.writer();
    const color = ConsoleStyle.init(file);
    {
        const id = std.mem.indexOf(u8, info.name, "/").?;
        try color.setColor(choice);
        try writer.print("  {s}", .{info.name[0..id]});
        try color.reset();
        try writer.writeByte('/');
        try color.setColor(choice);
        try writer.print("{s} ", .{info.name[id + 1 ..]});

        if (info.is_fork) try writer.writeAll("🔗 ");
        if (info.is_private) try writer.writeAll("🔒 ");
        if (info.is_template) try writer.writeAll("🗒; ");
        if (info.is_archived) try writer.writeAll("📦 ");
        try writer.writeByte('\n');

        try color.reset();

        try writer.writeAll("  ");
        try writer.writeByteNTimes('~', info.name.len);
        try writer.writeByte('\n');
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

        const data = @field(info, field.name);
        if (field.type == []const u8) {
            if (!std.mem.eql(u8, data, "")) {
                try writer.writeByte('-');

                try color.setColor(choice);
                try writer.print(" {s}", .{field.name});
                try color.reset();

                try writer.print(": {s}\n", .{data});
            }
        } else {
            if (data != 0) {
                try writer.writeByte('-');

                try color.setColor(choice);
                try writer.print(" {s}", .{field.name});
                try color.reset();

                try writer.print(": {}\n", .{data});
            }
        }
    }

    try writer.writeByte('\n');
}
