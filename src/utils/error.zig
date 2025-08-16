const std = @import("std");

pub const SuperDiffError = error{
    NotGitRepository,
    NoAuthorFound,
    NoCommitsFound,
    InvalidSquashRange,
    GitOperationFailed,
    FileWriteError,
    InvalidDateRange,
    WorktreeError,
    CherryPickFailed,
    StdoutStreamTooLong,
    StderrStreamTooLong,
} || std.mem.Allocator.Error || std.process.Child.RunError || std.fs.File.WriteError;

pub fn handleError(err: anyerror, stderr: anytype) void {
    switch (err) {
        error.NotGitRepository => {
            stderr.writeAll("Not a git repository.\n") catch {};
        },
        error.NoAuthorFound => {
            stderr.writeAll("Could not determine author; pass --author \"Name <email>\"\n") catch {};
        },
        error.NoCommitsFound => {
            stderr.writeAll("No commits found.\nTip: try --who committer, or --range --all, or relax --since/--until.\n") catch {};
        },
        error.InvalidSquashRange => {
            stderr.writeAll("squash mode requires --range A..B (not --all). Example: --range origin/main..HEAD\n") catch {};
        },
        error.GitOperationFailed => {
            stderr.writeAll("Git operation failed.\n") catch {};
        },
        error.FileWriteError => {
            stderr.writeAll("Failed to write output file.\n") catch {};
        },
        error.InvalidDateRange => {
            stderr.writeAll("Invalid date range specified.\n") catch {};
        },
        error.WorktreeError => {
            stderr.writeAll("Failed to create or manage temporary worktree.\n") catch {};
        },
        error.CherryPickFailed => {
            stderr.writeAll("Cherry-pick operation failed.\n") catch {};
        },
        error.StdoutStreamTooLong => {
            stderr.writeAll("Output too large. Consider using --stat or more specific filters.\n") catch {};
        },
        error.StderrStreamTooLong => {
            stderr.writeAll("Error output too large.\n") catch {};
        },
        error.OutOfMemory => {
            stderr.writeAll("Out of memory.\n") catch {};
        },
        else => {
            stderr.print("Unexpected error: {}\n", .{err}) catch {};
        },
    }
}

pub fn printNoCommitsMessage(stderr: anytype, author: []const u8, range: []const u8) void {
    stderr.print("No commits found for \"{s}\" in range {s} with the given filters.\n", .{ author, range }) catch {};
    stderr.writeAll("Tip: try --who committer, or --range --all, or relax --since/--until.\n") catch {};
}
