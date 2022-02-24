const std = @import("std");
const json = std.json;
const mem = std.mem;
const allocPrint = std.fmt.allocPrint;
const zfetch = @import("zfetch");
const utils = @import("utils.zig");
const TtyColor = utils.TtyColor;
const Host = @import("hosts.zig").Host;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const stdout = std.io.getStdOut().writer();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try zfetch.init();
    defer zfetch.deinit();

    const project = args[1];
    const url = if (mem.startsWith(u8, project, "http:") or mem.startsWith(u8, project, "https:")) blk: {
        break :blk try allocator.dupe(u8, project);
    } else switch (std.mem.count(u8, project, "/")) {
        1 => try allocPrint(allocator, "https://api.github.com/repos/{s}", .{project}),
        2 => blk: {
            var tokenizer = std.mem.tokenize(u8, project, "/");
            const host_name = tokenizer.next().?;
            const author_name = tokenizer.next().?;
            const project_name = tokenizer.rest();

            if (Host.match(host_name)) |host| break :blk switch (host) {
                .github => try allocPrint(allocator, "https://api.github.com/repos/{s}/{s}", .{ author_name, project_name }),
                .gitlab => try allocPrint(allocator, "https://gitlab.com/api/v4/projects/{s}%2F{s}", .{ author_name, project_name }),
                .codeberg => try allocPrint(allocator, "https://codeberg.org/api/v1/repos/{s}/{s}", .{ author_name, project_name }),
            } else {
                break :blk try allocPrint(allocator, "https://{s}", .{project});
            }
        },
        else => {
            std.log.err("malformed url/project name", .{});
            std.process.exit(1);
        },
    };
    defer allocator.free(url);

    var info = try Host.request(.github, allocator, url);
    defer info.free(allocator);

    const color = TtyColor(@TypeOf(stdout)).init(stdout);
    {
        try color.setColor(.red);

        try stdout.print("  {s} ", .{info.name});
        if (info.is_fork) try stdout.writeAll("🔗 ");
        if (info.is_private) try stdout.writeAll("🔒 ");
        if (info.is_template) try stdout.writeAll("🗒; ");
        if (info.is_archived) try stdout.writeAll("📦 ");
        try stdout.writeByte('\n');

        try color.setColor(.reset);
    }
    {
        var x: usize = 0;
        while (x < info.description.len) {
            const end = blk: {
                if (x + 50 >= info.description.len) {
                    break :blk info.description.len - x;
                } else {
                    break :blk 50;
                }
            };

            const str = std.mem.trimLeft(u8, info.description[x .. x + end], " ");
            try stdout.print("{s}\n", .{str});
            x += end;
        }
        try stdout.writeByte('\n');
    }
    try stdout.print("- repository: {s}\n", .{info.repository});
    try stdout.print("- license: {s}\n", .{info.license});
    try stdout.print("- default branch: {s}\n", .{info.branch});
    try stdout.print("- created: {s}\n", .{info.created[0..10]});
    // TODO: print in form "x hours ago" for below
    try stdout.print("- modified: {s}\n", .{info.modified[0..10]});
    try stdout.print("- language: {s}\n", .{info.language});
    try stdout.print("- size: {} KB\n", .{info.size});
    try stdout.print("- stars: {}\n", .{info.stars});
    try stdout.print("- watches: {}\n", .{info.watches});
    try stdout.print("- forks: {}\n", .{info.forks});

    std.log.info("All your get requests are belong to us.", .{});
}
