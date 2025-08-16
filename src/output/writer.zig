const std = @import("std");

pub const OutputWriter = struct {
    allocator: std.mem.Allocator,
    file: ?std.fs.File,
    writer: std.io.AnyWriter,

    pub fn init(allocator: std.mem.Allocator, output_path: ?[]const u8) !OutputWriter {
        if (output_path) |path| {
            const file = std.fs.cwd().createFile(path, .{}) catch |err| {
                switch (err) {
                    error.AccessDenied,
                    error.FileNotFound,
                    error.NoSpaceLeft,
                    error.DeviceBusy,
                    => return error.FileWriteError,
                    else => return err,
                }
            };

            return OutputWriter{
                .allocator = allocator,
                .file = file,
                .writer = file.writer().any(),
            };
        } else {
            return OutputWriter{
                .allocator = allocator,
                .file = null,
                .writer = std.io.getStdOut().writer().any(),
            };
        }
    }

    pub fn deinit(self: *OutputWriter) void {
        if (self.file) |file| {
            file.close();
        }
    }

    pub fn write(self: *OutputWriter, data: []const u8) !void {
        try self.writer.writeAll(data);
    }

    pub fn writeAll(self: *OutputWriter, data: []const u8) !void {
        try self.writer.writeAll(data);
    }
};
