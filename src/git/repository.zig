const std = @import("std");
const error_utils = @import("../utils/error.zig");

pub const Repository = struct {
    allocator: std.mem.Allocator,
    git_dir: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator) !Repository {
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "git", "rev-parse", "--git-dir" },
            .cwd = null,
        }) catch {
            return error.NotGitRepository;
        };
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);

        if (result.term.Exited != 0) {
            return error.NotGitRepository;
        }

        const git_dir = std.mem.trim(u8, result.stdout, " \t\n\r");
        return Repository{
            .allocator = allocator,
            .git_dir = try allocator.dupe(u8, git_dir),
        };
    }

    pub fn deinit(self: *Repository) void {
        if (self.git_dir) |git_dir| {
            self.allocator.free(git_dir);
        }
    }

    pub fn getDefaultAuthor(self: *Repository) ![]const u8 {
        if (self.getConfigValue("user.email")) |email| {
            return email;
        } else |_| {}

        if (self.getConfigValue("user.name")) |name| {
            return name;
        } else |_| {}

        return error.NoAuthorFound;
    }

    fn getConfigValue(self: *Repository, key: []const u8) ![]const u8 {
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "git", "config", "--get", key },
            .cwd = null,
        }) catch {
            return error.GitOperationFailed;
        };
        defer self.allocator.free(result.stderr);

        if (result.term.Exited != 0) {
            self.allocator.free(result.stdout);
            return error.GitOperationFailed;
        }

        const value = std.mem.trim(u8, result.stdout, " \t\n\r");
        const owned_value = try self.allocator.dupe(u8, value);
        self.allocator.free(result.stdout);
        return owned_value;
    }

    pub fn hasUpstream(self: *Repository) bool {
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}" },
            .cwd = null,
        }) catch {
            return false;
        };
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        return result.term.Exited == 0;
    }

    pub fn isRangeEmpty(self: *Repository, range: []const u8) bool {
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "git", "rev-list", range, "--max-count=1" },
            .cwd = null,
        }) catch {
            return true;
        };
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        if (result.term.Exited != 0) {
            return true;
        }

        const trimmed = std.mem.trim(u8, result.stdout, " \t\n\r");
        return trimmed.len == 0;
    }
};