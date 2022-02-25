const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;
const allocPrint = std.fmt.allocPrint;
const utils = @import("utils.zig");
const Info = @import("Info.zig");

pub const Host = enum {
    github,
    gitlab,
    codeberg,
    default,

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

    pub fn getUrl(host: Host, allocator: Allocator, author: []const u8, project: []const u8) ![]const u8 {
        return switch (host) {
            .default, .github => try allocPrint(allocator, "https://api.github.com/repos/{s}/{s}", .{ author, project }),
            .gitlab => try allocPrint(allocator, "https://gitlab.com/api/v4/projects/{s}%2F{s}?license=1", .{ author, project }),
            .codeberg => try allocPrint(allocator, "https://codeberg.org/api/v1/repos/{s}/{s}", .{ author, project }),
        };
    }

    pub fn request(host: Host, allocator: Allocator, url: []const u8) !Info {
        return switch (host) {
            .github, .default => try Github.request(allocator, url),
            .codeberg => try Gitea.request(allocator, url),
            .gitlab => try Gitlab.request(allocator, url),
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

const Gitlab = struct {
    const Query = struct {
        path_with_namespace: []const u8,
        description: []const u8,
        license: struct { nickname: []const u8 },
        web_url: []const u8,
        star_count: u32,
        forks_count: u32,
        created_at: []const u8,
        last_activity_at: []const u8,
        default_branch: []const u8,

        pub fn free(self: *@This(), allocator: Allocator) void {
            allocator.free(self.path_with_namespace);
            allocator.free(self.description);
            allocator.free(self.web_url);
            allocator.free(self.license.nickname);
            allocator.free(self.created_at);
            allocator.free(self.last_activity_at);
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
            .name = try allocator.dupe(u8, query.path_with_namespace),
            .is_private = false,
            .is_fork = false,
            .is_archived = false,
            .is_template = false,
            .description = try allocator.dupe(u8, query.description),
            .repository = try allocator.dupe(u8, query.web_url),
            .language = try allocator.dupe(u8, ""),
            .size = 0,
            .stars = query.star_count,
            .watches = 0,
            .forks = query.forks_count,
            .license = try allocator.dupe(u8, query.license.nickname),
            .created = try allocator.dupe(u8, query.created_at),
            .modified = try allocator.dupe(u8, query.last_activity_at),
            .branch = try allocator.dupe(u8, query.default_branch),
        };
    }
};
