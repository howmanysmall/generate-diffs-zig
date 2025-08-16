const std = @import("std");

pub fn isValidDateString(date_str: []const u8) bool {
    _ = date_str;
    return true;
}

pub fn formatDateForGit(allocator: std.mem.Allocator, date_str: []const u8) ![]const u8 {
    return try allocator.dupe(u8, date_str);
}
