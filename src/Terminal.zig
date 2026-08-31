//! wrapper around std.Io.Terminal that gives us a convenient
//! init and print method.

const Terminal = @This();

const std = @import("std");
const ColorScheme = @import("ColorScheme.zig");

const tty = std.Io.Terminal;
const File = std.Io.File;

instance: tty,

pub fn init(io: std.Io, file: File, writer: *std.Io.Writer) !Terminal {
    const terminal_mode: std.Io.Terminal.Mode = try .detect(io, file, false, false);
    return .{
        .instance = .{ .writer = writer, .mode = terminal_mode },
    };
}

pub fn print(
    terminal: Terminal,
    style: ColorScheme.Style,
    comptime format: []const u8,
    args: anytype,
) void {
    for (style) |color| {
        terminal.instance.setColor(color) catch {};
    }

    terminal.instance.writer.print(format, args) catch {};

    if (style.len > 0) {
        terminal.instance.setColor(.reset) catch {};
    }
}
