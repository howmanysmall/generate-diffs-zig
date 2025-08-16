const std = @import("std");
const commit = @import("commit.zig");

pub const DiffOptions = struct {
    show_stat: bool = false,
    no_color: bool = true,
    no_notes: bool = true,
    no_renames: bool = true,
};

pub fn generateSingleCommitDiff(
    allocator: std.mem.Allocator,
    commit_hash: commit.CommitHash,
    options: DiffOptions,
) ![]const u8 {
    var argv = std.ArrayList([]const u8).init(allocator);
    defer argv.deinit();

    try argv.appendSlice(&[_][]const u8{ "git", "show" });

    if (options.no_color) {
        try argv.append("--no-color");
    }

    if (options.show_stat) {
        try argv.append("--stat");
    } else {
        try argv.append("--patch");
    }

    if (options.no_notes) {
        try argv.append("--no-notes");
    }

    if (options.no_renames) {
        try argv.append("--no-renames");
    }

    if (options.show_stat) {
        try argv.append("--pretty=format:commit %H%nAuthor: %an <%ae>%nCommitter: %cn <%ce>%nDate:   %ad%n%n%s%n");
    }

    try argv.append(commit_hash);

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv.items,
        .cwd = null,
    }) catch {
        return error.GitOperationFailed;
    };
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        allocator.free(result.stdout);
        return error.GitOperationFailed;
    }

    return result.stdout;
}

pub fn generateMultipleCommitDiffs(
    allocator: std.mem.Allocator,
    commit_hashes: []const commit.CommitHash,
    options: DiffOptions,
) ![]const u8 {
    if (commit_hashes.len == 0) {
        return try allocator.dupe(u8, "");
    }

    var argv = std.ArrayList([]const u8).init(allocator);
    defer argv.deinit();

    try argv.appendSlice(&[_][]const u8{ "git", "show" });

    if (options.no_color) {
        try argv.append("--no-color");
    }

    if (options.show_stat) {
        try argv.append("--stat");
        try argv.append("--pretty=format:commit %H%nAuthor: %an <%ae>%nCommitter: %cn <%ce>%nDate:   %ad%n%n%s%n");
    } else {
        try argv.append("--patch");
    }

    if (options.no_notes) {
        try argv.append("--no-notes");
    }

    if (options.no_renames) {
        try argv.append("--no-renames");
    }

    try argv.appendSlice(commit_hashes);

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv.items,
        .cwd = null,
    }) catch {
        return error.GitOperationFailed;
    };
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        allocator.free(result.stdout);
        return error.GitOperationFailed;
    }

    return result.stdout;
}

pub fn generateRangeDiff(
    allocator: std.mem.Allocator,
    from: []const u8,
    to: []const u8,
    options: DiffOptions,
) ![]const u8 {
    var argv = std.ArrayList([]const u8).init(allocator);
    defer argv.deinit();

    try argv.appendSlice(&[_][]const u8{ "git", "diff" });

    if (options.no_color) {
        try argv.append("--no-color");
    }

    if (options.show_stat) {
        try argv.append("--stat");
    }

    const range = try std.fmt.allocPrint(allocator, "{s}...{s}", .{ from, to });
    defer allocator.free(range);
    try argv.append(range);

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv.items,
        .cwd = null,
    }) catch {
        return error.GitOperationFailed;
    };
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        allocator.free(result.stdout);
        return error.GitOperationFailed;
    }

    return result.stdout;
}