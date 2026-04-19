const std = @import("std");
const flags = @import("flags");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    const args = try init.minimal.args.toSlice(gpa);
    defer gpa.free(args);

    const options = flags.parse(io, args, "trailing", Flags, .{});

    var stdout_writer = std.Io.File.stdout().writer(io, &.{});
    try std.json.Stringify.value(
        options,
        .{ .whitespace = .indent_2 },
        &stdout_writer.interface,
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
