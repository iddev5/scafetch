const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;
const utils = @import("utils.zig");
const common = @import("common.zig");
const Info = common.Info;

allocator: Allocator,
url: []const u8,

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

const Self = @This();
pub fn init(allocator: Allocator, url: []const u8) Self {
    return .{
        .allocator = allocator,
        .url = url,
    };
}

pub fn request(self: *Self) !Info {
    const source = try utils.requestGet(self.allocator, self.url);
    defer self.allocator.free(source);
    var query = blk: {
        @setEvalBranchQuota(6000);
        var tokens = json.TokenStream.init(source);
        var query = try json.parse(Query, &tokens, .{
            .allocator = self.allocator,
            .ignore_unknown_fields = true,
        });
        errdefer query.free(self.allocator);
        break :blk query;
    };
    defer query.free(self.allocator);

    return Info{
        .name = try self.allocator.dupe(u8, query.full_name),
        .is_private = query.private,
        .is_fork = query.fork,
        .is_archived = query.archived,
        .is_template = query.is_template,
        .description = try self.allocator.dupe(u8, query.description),
        .repository = try self.allocator.dupe(u8, query.html_url),
        .language = try self.allocator.dupe(u8, query.language),
        .size = query.size,
        .stars = query.stargazers_count,
        .watches = query.watchers_count,
        .forks = query.forks_count,
        .license = try self.allocator.dupe(u8, query.license.name),
        .created = try self.allocator.dupe(u8, query.created_at),
        .modified = try self.allocator.dupe(u8, query.updated_at),
        .branch = try self.allocator.dupe(u8, query.default_branch),
    };
}
