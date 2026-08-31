const std = @import("std");
const flags = @import("flags");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    const args = try init.minimal.args.toSlice(gpa);
    defer gpa.free(args);

    _ = flags.parse(io, args, "colors", Flags, .{
        // Use the `colors` option to provide a colorscheme for the error/help messages.
        // Specifying this as empty: `.colors = &.{}` will disable colors.
        // Each field is a list of type `std.io.tty.Color`.
        .colors = &flags.ColorScheme{
            .error_label = &.{ .bright_red, .bold },
            .command_name = &.{.bright_green},
            .header = &.{ .yellow, .bold },
            .usage = &.{.dim},
        },
    });
}

const Flags = struct {
    pub const description =
        \\Showcase of terminal color options.
    ;

    foo: bool,
    bar: []const u8,
};
