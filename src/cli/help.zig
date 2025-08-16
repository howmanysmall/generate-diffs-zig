const std = @import("std");

pub fn printUsage(writer: anytype) !void {
    try writer.writeAll(
        \\Usage: super-diff [options]
        \\
        \\Creates a "super diff" of commits authored by you (or a specified person).
        \\
        \\Options:
        \\  --author "Name <email>"    Value to match against author/committer (see --who).
        \\                             Defaults to your git config: user.email or user.name.
        \\  --who author|committer|either
        \\                             Which identity to match (default: either).
        \\  --since "DATE"             Only include commits after this date (e.g., "2025-01-01", "2 weeks ago").
        \\  --until "DATE"             Only include commits up to this date.
        \\  --range A..B|--all|REV     Commit range/revisions to search.
        \\                             Default behavior:
        \\                               1) Try @{upstream}..HEAD if upstream exists
        \\                               2) If that yields no commits, fallback to --all
        \\  --mode concat|squash       Output style:
        \\                               concat (default): concatenates per-commit diffs
        \\                               squash: single cumulative diff (requires A..B range)
        \\  --output FILE              Write diff to FILE (defaults to stdout).
        \\  --stat                     Show --stat instead of full patch.
        \\  --help                     Show this help.
        \\
        \\Notes:
        \\- If you've already pushed everything, @{upstream}..HEAD is empty; we now auto-fallback to --all.
        \\- "squash" mode needs a real A..B range; it will error if you pass --all.
        \\
    );
}