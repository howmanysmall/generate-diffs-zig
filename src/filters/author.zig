const std = @import("std");

pub fn matchesAuthor(author_to_match: []const u8, commit_author: []const u8) bool {
    return std.mem.indexOf(u8, commit_author, author_to_match) != null;
}

pub fn matchesCommitter(committer_to_match: []const u8, commit_committer: []const u8) bool {
    return std.mem.indexOf(u8, commit_committer, committer_to_match) != null;
}

pub fn parseEmailFromIdentity(identity: []const u8) ?[]const u8 {
    if (std.mem.lastIndexOf(u8, identity, '<')) |start| {
        if (std.mem.lastIndexOf(u8, identity, '>')) |end| {
            if (end > start + 1) {
                return identity[start + 1 .. end];
            }
        }
    }
    return null;
}

pub fn parseNameFromIdentity(identity: []const u8) ?[]const u8 {
    if (std.mem.lastIndexOf(u8, identity, '<')) |email_start| {
        const name = std.mem.trim(u8, identity[0..email_start], " \t");
        if (name.len > 0) {
            return name;
        }
    }
    return std.mem.trim(u8, identity, " \t");
}