const std = @import("std");
const cli = @import("cli/args.zig");
const help = @import("cli/help.zig");
const repository = @import("git/repository.zig");
const commit = @import("git/commit.zig");
const error_utils = @import("utils/error.zig");
const concat = @import("output/concat.zig");
const squash = @import("output/squash.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stderr = std.io.getStdErr().writer();
    const stdout = std.io.getStdOut().writer();

    var args = cli.Args.parse(allocator) catch |err| {
        switch (err) {
            error.UnknownArgument,
            error.MissingAuthorValue,
            error.MissingWhoValue,
            error.MissingSinceValue,
            error.MissingUntilValue,
            error.MissingRangeValue,
            error.MissingModeValue,
            error.MissingOutputValue,
            error.InvalidWhoValue,
            error.InvalidModeValue,
            => {
                try help.printUsage(stderr);
                std.process.exit(1);
            },
            else => return err,
        }
    };
    defer args.deinit(allocator);

    if (args.help) {
        try help.printUsage(stdout);
        return;
    }

    var repo = repository.Repository.init(allocator) catch |err| {
        switch (err) {
            error.NotGitRepository => {
                error_utils.handleError(err, stderr);
                std.process.exit(1);
            },
            else => return err,
        }
    };
    defer repo.deinit();

    var author = args.author;
    var author_needs_free = false;
    if (author == null) {
        author = repo.getDefaultAuthor() catch |err| {
            switch (err) {
                error.NoAuthorFound => {
                    error_utils.handleError(err, stderr);
                    std.process.exit(1);
                },
                else => return err,
            }
        };
        author_needs_free = true;
    }
    defer if (author_needs_free) {
        if (author) |a| allocator.free(a);
    };

    var range = args.range;
    if (range == null) {
        if (repo.hasUpstream()) {
            range = "@{upstream}..HEAD";
        } else {
            range = "--all";
        }
    }

    var range_for_search = range.?;
    if (std.mem.eql(u8, range.?, "@{upstream}..HEAD")) {
        if (repo.isRangeEmpty("@{upstream}..HEAD")) {
            range_for_search = "--all";
            try stderr.writeAll("Note: @{upstream}..HEAD is empty; falling back to --all.\n");
        }
    }

    const filter = commit.CommitFilter{
        .author = author,
        .who = args.who,
        .since = args.since,
        .until = args.until,
        .range = range_for_search,
    };

    var commits = commit.getCommitList(allocator, filter) catch |err| {
        error_utils.handleError(err, stderr);
        std.process.exit(1);
    };
    defer {
        for (commits.items) |commit_hash| {
            allocator.free(commit_hash);
        }
        commits.deinit();
    }

    if (commits.items.len == 0) {
        error_utils.printNoCommitsMessage(stderr, author.?, range_for_search);
        std.process.exit(0);
    }

    switch (args.mode) {
        .concat => {
            concat.generateConcatOutput(
                allocator,
                commits.items,
                args.show_stat,
                args.output,
            ) catch |err| {
                switch (err) {
                    error.GitOperationFailed,
                    error.FileWriteError,
                    error.OutOfMemory,
                    => {
                        error_utils.handleError(err, stderr);
                        std.process.exit(1);
                    },
                    else => {
                        error_utils.handleError(err, stderr);
                        std.process.exit(1);
                    },
                }
            };
        },
        .squash => {
            if (std.mem.indexOf(u8, range.?, "..") == null) {
                error_utils.handleError(error.InvalidSquashRange, stderr);
                std.process.exit(1);
            }

            squash.generateSquashOutput(
                allocator,
                commits.items,
                range.?,
                args.show_stat,
                args.output,
            ) catch |err| {
                switch (err) {
                    error.GitOperationFailed,
                    error.FileWriteError,
                    error.OutOfMemory,
                    error.InvalidSquashRange,
                    error.WorktreeError,
                    error.CherryPickFailed,
                    => {
                        error_utils.handleError(err, stderr);
                        std.process.exit(1);
                    },
                    else => {
                        error_utils.handleError(err, stderr);
                        std.process.exit(1);
                    },
                }
            };
        },
    }
}
