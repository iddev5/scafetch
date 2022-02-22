const std = @import("std");
const json = std.json;
const zfetch = @import("zfetch");

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try zfetch.init();
    defer zfetch.deinit();

    var headers = zfetch.Headers.init(allocator);
    defer headers.deinit();

    try headers.appendValue("Accept", "application/json");

    const url = try std.fmt.allocPrint(allocator, "https://api.github.com/repos/{s}", .{args[1]});
    defer allocator.free(url);

    var req = try zfetch.Request.init(allocator, url, null);
    defer req.deinit();

    try req.do(.GET, headers, null);

    const stdout = std.io.getStdOut().writer();
    const reader = req.reader();

    if (req.status.code != 200) {
        std.log.err("request return status code: {}: {s}\n", .{ req.status.code, req.status.reason });
        std.process.exit(1);
    }

    var buf: [1024]u8 = undefined;
    var source = std.ArrayList(u8).init(allocator);
    defer source.deinit();

    while (true) {
        const read = try reader.read(&buf);
        if (read == 0) break;

        try source.appendSlice(buf[0..read]);
    }

    const Query = struct {
        full_name: []const u8,
        description: []const u8,
        html_url: []const u8,
        language: []const u8,
        size: u32,
        stargazers_count: u32,
        watchers_count: u32,
        forks_count: u32,

        pub fn free(self: *@This(), alloc: std.mem.Allocator) void {
            alloc.free(self.full_name);
            alloc.free(self.description);
            alloc.free(self.html_url);
            alloc.free(self.language);
        }
    };

    var info = blk: {
        @setEvalBranchQuota(2000);
        var tokens = json.TokenStream.init(source.items);
        var info = try json.parse(Query, &tokens, .{
            .allocator = allocator,
            .ignore_unknown_fields = true,
        });
        errdefer info.free(allocator);
        break :blk info;
    };
    defer info.free(allocator);

    try stdout.print("  {s}\n", .{info.full_name});
    try stdout.print("{s}\n\n", .{info.description});
    try stdout.print("- repository: {s}\n", .{info.html_url});
    try stdout.print("- language: {s}\n", .{info.language});
    try stdout.print("- size: {} KB\n", .{info.size});
    try stdout.print("- stars: {}\n", .{info.stargazers_count});
    try stdout.print("- watches: {}\n", .{info.watchers_count});
    try stdout.print("- forks: {}\n", .{info.forks_count});

    std.log.info("All your get requests are belong to us.", .{});
}
