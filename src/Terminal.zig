const Terminal = @This();

const std = @import("std");
const ColorScheme = @import("ColorScheme.zig");

const tty = std.io.tty;
const File = std.fs.File;

write_buffer: [1024]u8 = undefined,
file: File,
writer: std.fs.File.Writer = undefined,
config: tty.Config = undefined,

pub fn init(file: File) Terminal {
    var term = Terminal{
        .file = file,
        .config = tty.detectConfig(file),
    };
    term.writer = term.file.writer(&term.write_buffer);
    return term;
}

pub fn print(
    term: *Terminal,
    style: ColorScheme.Style,
    comptime format: []const u8,
    args: anytype,
) void {
    const writer = &term.writer.interface;
    for (style) |color| {
        term.config.setColor(writer, color) catch @panic("Can't set color!");
    }

    writer.print(format, args) catch @panic("Print failed!");

    if (style.len > 0) {
        term.config.setColor(writer, .reset) catch @panic("Can't set color!");
    }
}

pub fn flush(term: *Terminal) void {
    term.writer.interface.flush() catch @panic("Flush failed!");
}
