const Terminal = @This();

const std = @import("std");
const ColorScheme = @import("ColorScheme.zig");

const Io = std.Io;
const File = Io.File;

term: Io.Terminal,

pub fn init(io: Io, file: File, writer: *std.Io.Writer) Terminal {
    return .{
        .term = .{
            .writer = writer,

            // WARNING unsure what to do with these bool flags
            .mode = Io.Terminal.Mode.detect(io, file, false, false) catch .no_color,
        },
    };
}

pub fn print(
    terminal: Terminal,
    style: ColorScheme.Style,
    comptime format: []const u8,
    args: anytype,
) void {
    const term = &terminal.term;

    for (style) |color| {
        term.setColor(color) catch {};
    }

    term.writer.print(format, args) catch {};

    if (style.len > 0) {
        term.setColor(.reset) catch {};
    }
}
