const Terminal = @This();

const std = @import("std");
const ColorScheme = @import("ColorScheme.zig");

const tty = std.Io.tty;
const File = std.fs.File;

writer: *std.Io.Writer,
config: tty.Config,

pub fn init(file: File, writer: *std.Io.Writer) Terminal {
    return .{
        .writer = writer,
        .config = tty.detectConfig(file),
    };
}

pub fn print(
    terminal: Terminal,
    style: ColorScheme.Style,
    comptime format: []const u8,
    args: anytype,
) void {
    for (style) |color| {
        terminal.config.setColor(terminal.writer, color) catch {};
    }

    terminal.writer.print(format, args) catch {};

    if (style.len > 0) {
        terminal.config.setColor(terminal.writer, .reset) catch {};
    }
}
