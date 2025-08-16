const std = @import("std");

pub const WhoFilter = enum {
    author,
    committer,
    either,

    pub fn fromString(str: []const u8) !WhoFilter {
        if (std.mem.eql(u8, str, "author")) return .author;
        if (std.mem.eql(u8, str, "committer")) return .committer;
        if (std.mem.eql(u8, str, "either")) return .either;
        return error.InvalidWhoFilter;
    }
};

pub const OutputMode = enum {
    concat,
    squash,

    pub fn fromString(str: []const u8) !OutputMode {
        if (std.mem.eql(u8, str, "concat")) return .concat;
        if (std.mem.eql(u8, str, "squash")) return .squash;
        return error.InvalidOutputMode;
    }
};

pub const Args = struct {
    author: ?[]const u8 = null,
    who: WhoFilter = .either,
    since: ?[]const u8 = null,
    until: ?[]const u8 = null,
    range: ?[]const u8 = null,
    mode: OutputMode = .concat,
    output: ?[]const u8 = null,
    show_stat: bool = false,
    help: bool = false,

    pub fn parse(allocator: std.mem.Allocator) !Args {
        var args = Args{};
        const argv = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, argv);

        var i: usize = 1;
        while (i < argv.len) {
            const arg = argv[i];

            if (std.mem.eql(u8, arg, "--author")) {
                if (i + 1 >= argv.len) return error.MissingAuthorValue;
                i += 1;
                args.author = try allocator.dupe(u8, argv[i]);
            } else if (std.mem.eql(u8, arg, "--who")) {
                if (i + 1 >= argv.len) return error.MissingWhoValue;
                i += 1;
                args.who = WhoFilter.fromString(argv[i]) catch {
                    std.log.err("Invalid --who value: {s} (use author|committer|either)", .{argv[i]});
                    return error.InvalidWhoValue;
                };
            } else if (std.mem.eql(u8, arg, "--since")) {
                if (i + 1 >= argv.len) return error.MissingSinceValue;
                i += 1;
                args.since = try allocator.dupe(u8, argv[i]);
            } else if (std.mem.eql(u8, arg, "--until")) {
                if (i + 1 >= argv.len) return error.MissingUntilValue;
                i += 1;
                args.until = try allocator.dupe(u8, argv[i]);
            } else if (std.mem.eql(u8, arg, "--range")) {
                if (i + 1 >= argv.len) return error.MissingRangeValue;
                i += 1;
                args.range = try allocator.dupe(u8, argv[i]);
            } else if (std.mem.eql(u8, arg, "--mode")) {
                if (i + 1 >= argv.len) return error.MissingModeValue;
                i += 1;
                args.mode = OutputMode.fromString(argv[i]) catch {
                    std.log.err("Invalid --mode value: {s} (use concat|squash)", .{argv[i]});
                    return error.InvalidModeValue;
                };
            } else if (std.mem.eql(u8, arg, "--output")) {
                if (i + 1 >= argv.len) return error.MissingOutputValue;
                i += 1;
                args.output = try allocator.dupe(u8, argv[i]);
            } else if (std.mem.eql(u8, arg, "--stat")) {
                args.show_stat = true;
            } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                args.help = true;
            } else {
                std.log.err("Unknown argument: {s}", .{arg});
                return error.UnknownArgument;
            }

            i += 1;
        }

        return args;
    }

    pub fn deinit(self: *Args, allocator: std.mem.Allocator) void {
        if (self.author) |author| allocator.free(author);
        if (self.since) |since| allocator.free(since);
        if (self.until) |until| allocator.free(until);
        if (self.range) |range| allocator.free(range);
        if (self.output) |output| allocator.free(output);
    }
};
