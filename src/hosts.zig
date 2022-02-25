const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;
const utils = @import("utils.zig");
const Info = @import("Info.zig");

pub const Host = enum {
    github,
    gitlab,
    codeberg,

    const hosts_map = std.ComptimeStringMap(Host, .{
        .{ "github.com", .github },
        .{ "gitlab.com", .gitlab },
        .{ "codeberg.com", .codeberg },
        .{ "github", .github },
        .{ "gitlab", .gitlab },
        .{ "codeberg", .codeberg },
        .{ "gh", .github },
        .{ "gl", .gitlab },
        .{ "cb", .codeberg },
    });

    pub fn match(name: []const u8) ?Host {
        return Host.hosts_map.get(name);
    }

    pub fn request(host: Host, allocator: Allocator, url: []const u8) !Info {
        return switch (host) {
            .github => try Github.request(allocator, url),
            .codeberg => try Gitea.request(allocator, url),
            else => {
                std.log.err("host unimplemented", .{});
                std.process.exit(1);
            },
        };
    }
};

const Github = struct {
    const Query = struct {
        full_name: []const u8,
        private: bool,
        fork: bool,
        archived: bool,
        is_template: bool,
        description: []const u8,
        html_url: []const u8,
        language: []const u8,
        size: u32,
        stargazers_count: u32,
        watchers_count: u32,
        forks_count: u32,
        license: struct { name: []const u8 },
        created_at: []const u8,
        updated_at: []const u8,
        default_branch: []const u8,

        pub fn free(self: *@This(), allocator: Allocator) void {
            allocator.free(self.full_name);
            allocator.free(self.description);
            allocator.free(self.html_url);
            allocator.free(self.language);
            allocator.free(self.license.name);
            allocator.free(self.created_at);
            allocator.free(self.updated_at);
            allocator.free(self.default_branch);
        }
    };

    pub fn request(allocator: Allocator, url: []const u8) !Info {
        const source = try utils.requestGet(allocator, url);
        defer allocator.free(source);
        var query = blk: {
            @setEvalBranchQuota(6000);
            var tokens = json.TokenStream.init(source);
            var query = try json.parse(Query, &tokens, .{
                .allocator = allocator,
                .ignore_unknown_fields = true,
            });
            errdefer query.free(allocator);
            break :blk query;
        };
        defer query.free(allocator);

        return Info{
            .name = try allocator.dupe(u8, query.full_name),
            .is_private = query.private,
            .is_fork = query.fork,
            .is_archived = query.archived,
            .is_template = query.is_template,
            .description = try allocator.dupe(u8, query.description),
            .repository = try allocator.dupe(u8, query.html_url),
            .language = try allocator.dupe(u8, query.language),
            .size = query.size,
            .stars = query.stargazers_count,
            .watches = query.watchers_count,
            .forks = query.forks_count,
            .license = try allocator.dupe(u8, query.license.name),
            .created = try allocator.dupe(u8, query.created_at),
            .modified = try allocator.dupe(u8, query.updated_at),
            .branch = try allocator.dupe(u8, query.default_branch),
        };
    }
};

const Gitea = struct {
    const Query = struct {
        full_name: []const u8,
        private: bool,
        fork: bool,
        archived: bool,
        template: bool,
        description: []const u8,
        html_url: []const u8,
        size: u32,
        stars_count: u32,
        watchers_count: u32,
        forks_count: u32,
        created_at: []const u8,
        updated_at: []const u8,
        default_branch: []const u8,

        pub fn free(self: *@This(), allocator: Allocator) void {
            allocator.free(self.full_name);
            allocator.free(self.description);
            allocator.free(self.html_url);
            // allocator.free(self.language);
            // allocator.free(self.license.name);
            allocator.free(self.created_at);
            allocator.free(self.updated_at);
            allocator.free(self.default_branch);
        }
    };

    pub fn request(allocator: Allocator, url: []const u8) !Info {
        const source = try utils.requestGet(allocator, url);
        defer allocator.free(source);
        var query = blk: {
            @setEvalBranchQuota(6000);
            var tokens = json.TokenStream.init(source);
            var query = try json.parse(Query, &tokens, .{
                .allocator = allocator,
                .ignore_unknown_fields = true,
            });
            errdefer query.free(allocator);
            break :blk query;
        };
        defer query.free(allocator);

        return Info{
            .name = try allocator.dupe(u8, query.full_name),
            .is_private = query.private,
            .is_fork = query.fork,
            .is_archived = query.archived,
            .is_template = query.template,
            .description = try allocator.dupe(u8, query.description),
            .repository = try allocator.dupe(u8, query.html_url),
            .language = try allocator.dupe(u8, ""),
            .size = query.size,
            .stars = query.stars_count,
            .watches = query.watchers_count,
            .forks = query.forks_count,
            .license = try allocator.dupe(u8, ""),
            .created = try allocator.dupe(u8, query.created_at),
            .modified = try allocator.dupe(u8, query.updated_at),
            .branch = try allocator.dupe(u8, query.default_branch),
        };
    }
};
