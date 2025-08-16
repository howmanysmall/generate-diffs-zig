const std = @import("std");
const temp = @import("../utils/temp.zig");
const commit = @import("commit.zig");

pub const Worktree = struct {
    allocator: std.mem.Allocator,
    temp_dir: temp.TempDir,
    path: []const u8,

    pub fn create(allocator: std.mem.Allocator, base_commit: []const u8) !Worktree {
        var temp_dir = try temp.TempDir.create(allocator, "superdiff");
        errdefer temp_dir.deinit();

        const worktree_path = try allocator.dupe(u8, temp_dir.path);

        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "git", "worktree", "add", "--detach", worktree_path, base_commit },
            .cwd = null,
        }) catch {
            allocator.free(worktree_path);
            return error.WorktreeError;
        };
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);

        if (result.term.Exited != 0) {
            allocator.free(worktree_path);
            return error.WorktreeError;
        }

        return Worktree{
            .allocator = allocator,
            .temp_dir = temp_dir,
            .path = worktree_path,
        };
    }

    pub fn deinit(self: *Worktree) void {
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "git", "worktree", "remove", "--force", self.path },
            .cwd = null,
        }) catch return;
        self.allocator.free(result.stdout);
        self.allocator.free(result.stderr);

        self.allocator.free(self.path);
        self.temp_dir.deinit();
    }

    pub fn cherryPickCommit(self: *Worktree, commit_hash: commit.CommitHash) !void {
        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "git", "cherry-pick", "-n", "-X", "theirs", commit_hash },
            .cwd = self.path,
        }) catch {
            return error.CherryPickFailed;
        };
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        if (result.term.Exited != 0) {
            _ = std.process.Child.run(.{
                .allocator = self.allocator,
                .argv = &[_][]const u8{ "git", "add", "-A" },
                .cwd = self.path,
            }) catch {};

            _ = std.process.Child.run(.{
                .allocator = self.allocator,
                .argv = &[_][]const u8{ "git", "cherry-pick", "--continue" },
                .cwd = self.path,
            }) catch {};
        }
    }

    pub fn getMergeBase(allocator: std.mem.Allocator, from: []const u8, to: []const u8) ![]const u8 {
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "git", "merge-base", from, to },
            .cwd = null,
        }) catch {
            return error.GitOperationFailed;
        };
        defer allocator.free(result.stderr);

        if (result.term.Exited != 0) {
            allocator.free(result.stdout);
            return error.GitOperationFailed;
        }

        const base = std.mem.trim(u8, result.stdout, " \t\n\r");
        const owned_base = try allocator.dupe(u8, base);
        allocator.free(result.stdout);
        return owned_base;
    }
};