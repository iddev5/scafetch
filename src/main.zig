const std = @import("std");
const json = std.json;
const mem = std.mem;
const zfetch = @import("zfetch");
const Host = @import("hosts.zig").Host;
const AyArgparse = @import("ay-arg");

pub fn printVersion(writer: anytype) !void {
    try writer.writeAll("scafetch v0.1\n");
}

pub fn printHelp(writer: anytype) !void {
    try printVersion(writer);
    try writer.writeAll(
        \\usage: scafetch <author>/<repository>
        \\
        \\  -o, --host <host>       Select the host server, accepted values are
        \\                           github (default), gitlab and codeberg
        \\  -h, --help              Show this help message
        \\  -v, --version           Show the app version
        \\
        \\
    );
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const stdout_file = std.io.getStdOut();
    const stdout = std.io.getStdOut().writer();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const params = &[_]AyArgparse.ParamDesc{
        .{ .long = "host", .short = "o", .need_value = true },
        .{ .long = "version", .short = "v" },
        .{ .long = "help", .short = "h" },
    };

    if (args.len < 2) {
        try printHelp(stdout);
        std.process.exit(0);
    }

    var ap = AyArgparse.init(allocator, params[0..]);
    defer ap.deinit();
    try ap.parse(args[1..]);

    if (ap.arguments.get("version")) |_| {
        try printVersion(stdout);
        std.process.exit(0);
    }

    if (ap.arguments.get("help")) |_| {
        try printHelp(stdout);
        std.process.exit(0);
    }

    try zfetch.init();
    defer zfetch.deinit();

    const project = ap.positionals.items[0];
    var host_tag: Host = if (ap.arguments.get("host")) |h| std.meta.stringToEnum(Host, h) orelse {
        try printHelp(stdout);
        std.log.err("unknown host name: {s}\n", .{h});
        std.process.exit(1);
    } else .default;

    const url = if (mem.startsWith(u8, project, "http:") or mem.startsWith(u8, project, "https:")) blk: {
        break :blk try allocator.dupe(u8, project);
    } else blk: {
        var tokenizer = std.mem.tokenize(u8, project, "/");
        var author_name: []const u8 = undefined;
        var project_name: []const u8 = undefined;

        switch (std.mem.count(u8, project, "/")) {
            1 => {
                author_name = tokenizer.next().?;
                project_name = tokenizer.rest();
            },
            2 => {
                const host_name = tokenizer.next().?;
                author_name = tokenizer.next().?;
                project_name = tokenizer.rest();

                if (Host.match(host_name)) |host| {
                    if (host_tag != .default and host != host_tag) {
                        try printHelp(stdout);
                        std.log.err("mismatched host name in argument and in url", .{});
                        std.process.exit(1);
                    }

                    host_tag = host;
                }
            },
            else => {
                try printHelp(stdout);
                std.log.err("malformed url/project name", .{});
                std.process.exit(1);
            },
        }

        break :blk try Host.getUrl(host_tag, allocator, author_name, project_name);
    };
    defer allocator.free(url);

    var info = try Host.request(host_tag, allocator, url);
    defer info.free(allocator);

    try info.print(stdout_file);

    std.log.info("All your repo stats are belong to us.", .{});
}
