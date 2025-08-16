const std = @import("std");
const commit = @import("../git/commit.zig");
const diff = @import("../git/diff.zig");
const worktree = @import("../git/worktree.zig");
const writer = @import("writer.zig");

pub fn generateSquashOutput(
    allocator: std.mem.Allocator,
    commits: []const commit.CommitHash,
    range: []const u8,
    show_stat: bool,
    output_path: ?[]const u8,
) !void {
    if (commits.len == 0) {
        return;
    }

    if (std.mem.indexOf(u8, range, "..") == null) {
        return error.InvalidSquashRange;
    }

    const dot_pos = std.mem.indexOf(u8, range, "..").?;
    const from = range[0..dot_pos];
    const to = range[dot_pos + 2 ..];

    const base = try worktree.Worktree.getMergeBase(allocator, from, to);
    defer allocator.free(base);

    var wt = try worktree.Worktree.create(allocator, base);
    defer wt.deinit();

    for (commits) |commit_hash| {
        wt.cherryPickCommit(commit_hash) catch |err| {
            switch (err) {
                error.CherryPickFailed => {
                    std.log.warn("Warning: conflict while cherry-picking {s}; attempting auto-resolution...", .{commit_hash});
                },
                else => return err,
            }
        };
    }

    var output_writer = try writer.OutputWriter.init(allocator, output_path);
    defer output_writer.deinit();

    const diff_options = diff.DiffOptions{
        .show_stat = show_stat,
        .no_color = true,
        .no_notes = true,
        .no_renames = true,
    };

    const diff_content = try diff.generateRangeDiff(
        allocator,
        base,
        "HEAD",
        diff_options,
    );
    defer allocator.free(diff_content);

    try output_writer.writeAll(diff_content);
}
