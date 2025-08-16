const std = @import("std");

pub const TempDir = struct {
    allocator: std.mem.Allocator,
    path: []const u8,

    pub fn create(allocator: std.mem.Allocator, prefix: []const u8) !TempDir {
        var random = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
        const random_suffix = random.random().int(u32);

        const dir_name = try std.fmt.allocPrint(
            allocator,
            "{s}-{x}",
            .{ prefix, random_suffix },
        );
        defer allocator.free(dir_name);

        const temp_path = try std.fs.path.join(allocator, &[_][]const u8{
            "/tmp",
            dir_name,
        });

        std.fs.makeDirAbsolute(temp_path) catch |err| {
            allocator.free(temp_path);
            return err;
        };

        return TempDir{
            .allocator = allocator,
            .path = temp_path,
        };
    }

    pub fn deinit(self: *TempDir) void {
        std.fs.deleteTreeAbsolute(self.path) catch {};
        self.allocator.free(self.path);
    }
};