const std = @import("std");
const commit = @import("../git/commit.zig");
const diff = @import("../git/diff.zig");
const writer = @import("writer.zig");

pub fn generateConcatOutput(
    allocator: std.mem.Allocator,
    commits: []const commit.CommitHash,
    show_stat: bool,
    output_path: ?[]const u8,
) !void {
    if (commits.len == 0) {
        return;
    }

    var output_writer = try writer.OutputWriter.init(allocator, output_path);
    defer output_writer.deinit();

    const diff_options = diff.DiffOptions{
        .show_stat = show_stat,
        .no_color = true,
        .no_notes = true,
        .no_renames = true,
    };

    const diff_content = try diff.generateMultipleCommitDiffs(
        allocator,
        commits,
        diff_options,
    );
    defer allocator.free(diff_content);

    try output_writer.writeAll(diff_content);
}
