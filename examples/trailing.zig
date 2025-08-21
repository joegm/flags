const std = @import("std");
const flags = @import("flags");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(gpa.allocator());
    defer std.process.argsFree(gpa.allocator(), args);

    const options = flags.parse(args, "trailing", Flags, .{});

    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    try std.json.Stringify.value(
        options,
        .{ .whitespace = .indent_2 },
        stdout,
    );
}

const Flags = struct {
    some_flag: bool,

    positional: struct {
        some_number: i32,
        maybe_number: ?i32,

        // The specially named 'trailing' positional field can be used to collect the remaining
        // positional arguments after all others have been parsed.
        //
        // Any argument after the first trailing positional argument will be included here, and
        // will not be parsed as a flag or command, even if it matches one, so having both a
        // trailing positional field and a command field is redundant.
        trailing: []const []const u8,
    },
};
