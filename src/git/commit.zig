const std = @import("std");
const cli = @import("../cli/args.zig");

pub const CommitHash = []const u8;

pub const CommitFilter = struct {
    author: ?[]const u8,
    who: cli.WhoFilter,
    since: ?[]const u8,
    until: ?[]const u8,
    range: []const u8,
};

pub fn getCommitList(
    allocator: std.mem.Allocator,
    filter: CommitFilter,
) !std.ArrayList(CommitHash) {
    var commits = std.ArrayList(CommitHash).init(allocator);
    errdefer {
        for (commits.items) |commit| {
            allocator.free(commit);
        }
        commits.deinit();
    }

    switch (filter.who) {
        .author => {
            try getCommitsByAuthor(allocator, &commits, filter);
        },
        .committer => {
            try getCommitsByCommitter(allocator, &commits, filter);
        },
        .either => {
            var by_author = std.ArrayList(CommitHash).init(allocator);
            defer {
                for (by_author.items) |commit| {
                    allocator.free(commit);
                }
                by_author.deinit();
            }

            var by_committer = std.ArrayList(CommitHash).init(allocator);
            defer {
                for (by_committer.items) |commit| {
                    allocator.free(commit);
                }
                by_committer.deinit();
            }

            try getCommitsByAuthor(allocator, &by_author, filter);
            try getCommitsByCommitter(allocator, &by_committer, filter);

            var seen = std.StringHashMap(void).init(allocator);
            defer seen.deinit();

            for (by_author.items) |commit| {
                if (!seen.contains(commit)) {
                    try seen.put(commit, {});
                    try commits.append(try allocator.dupe(u8, commit));
                }
            }

            for (by_committer.items) |commit| {
                if (!seen.contains(commit)) {
                    try seen.put(commit, {});
                    try commits.append(try allocator.dupe(u8, commit));
                }
            }
        },
    }

    return commits;
}

fn getCommitsByAuthor(
    allocator: std.mem.Allocator,
    commits: *std.ArrayList(CommitHash),
    filter: CommitFilter,
) !void {
    var argv = std.ArrayList([]const u8).init(allocator);
    defer argv.deinit();

    try argv.appendSlice(&[_][]const u8{ "git", "rev-list", filter.range, "--reverse" });

    var author_arg: ?[]const u8 = null;
    var since_arg: ?[]const u8 = null;
    var until_arg: ?[]const u8 = null;

    if (filter.author) |author| {
        author_arg = try std.fmt.allocPrint(allocator, "--author={s}", .{author});
        try argv.append(author_arg.?);
    }

    if (filter.since) |since| {
        since_arg = try std.fmt.allocPrint(allocator, "--since={s}", .{since});
        try argv.append(since_arg.?);
    }

    if (filter.until) |until| {
        until_arg = try std.fmt.allocPrint(allocator, "--until={s}", .{until});
        try argv.append(until_arg.?);
    }

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv.items,
        .cwd = null,
        .max_output_bytes = 100 * 1024 * 1024, // 100MB for large repos
    }) catch |err| {
        switch (err) {
            error.StdoutStreamTooLong => {
                std.log.err("Git output too large (>100MB). Consider using more specific filters.", .{});
                return error.GitOperationFailed;
            },
            error.StderrStreamTooLong => {
                std.log.err("Git error output too large. Check git command.", .{});
                return error.GitOperationFailed;
            },
            else => {
                std.log.err("Git command failed: {}", .{err});
                return error.GitOperationFailed;
            },
        }
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    defer {
        if (author_arg) |arg| allocator.free(arg);
        if (since_arg) |arg| allocator.free(arg);
        if (until_arg) |arg| allocator.free(arg);
    }

    if (result.term.Exited != 0) {
        if (result.stderr.len > 0) {
            std.log.err("Git error: {s}", .{result.stderr});
        }
        return;
    }

    var lines = std.mem.splitScalar(u8, result.stdout, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len > 0) {
            try commits.append(try allocator.dupe(u8, trimmed));
        }
    }
}

fn getCommitsByCommitter(
    allocator: std.mem.Allocator,
    commits: *std.ArrayList(CommitHash),
    filter: CommitFilter,
) !void {
    var argv = std.ArrayList([]const u8).init(allocator);
    defer argv.deinit();

    try argv.appendSlice(&[_][]const u8{ "git", "rev-list", filter.range, "--reverse" });

    var committer_arg: ?[]const u8 = null;
    var since_arg: ?[]const u8 = null;
    var until_arg: ?[]const u8 = null;

    if (filter.author) |author| {
        committer_arg = try std.fmt.allocPrint(allocator, "--committer={s}", .{author});
        try argv.append(committer_arg.?);
    }

    if (filter.since) |since| {
        since_arg = try std.fmt.allocPrint(allocator, "--since={s}", .{since});
        try argv.append(since_arg.?);
    }

    if (filter.until) |until| {
        until_arg = try std.fmt.allocPrint(allocator, "--until={s}", .{until});
        try argv.append(until_arg.?);
    }

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv.items,
        .cwd = null,
        .max_output_bytes = 100 * 1024 * 1024, // 100MB for large repos
    }) catch |err| {
        switch (err) {
            error.StdoutStreamTooLong => {
                std.log.err("Git output too large (>100MB). Consider using more specific filters.", .{});
                return error.GitOperationFailed;
            },
            error.StderrStreamTooLong => {
                std.log.err("Git error output too large. Check git command.", .{});
                return error.GitOperationFailed;
            },
            else => {
                std.log.err("Git command failed: {}", .{err});
                return error.GitOperationFailed;
            },
        }
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    defer {
        if (committer_arg) |arg| allocator.free(arg);
        if (since_arg) |arg| allocator.free(arg);
        if (until_arg) |arg| allocator.free(arg);
    }

    if (result.term.Exited != 0) {
        if (result.stderr.len > 0) {
            std.log.err("Git error: {s}", .{result.stderr});
        }
        return;
    }

    var lines = std.mem.splitScalar(u8, result.stdout, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len > 0) {
            try commits.append(try allocator.dupe(u8, trimmed));
        }
    }
}
