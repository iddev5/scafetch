const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Info = struct {
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
};
