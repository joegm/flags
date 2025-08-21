const std = @import("std");
const flags = @import("flags");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(gpa.allocator());
    defer std.process.argsFree(gpa.allocator(), args);

    const options = flags.parse(args, "overview", Flags, .{});

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
    // Optional description of the program.
    pub const description =
        \\This is a dummy command for testing purposes.
        \\There are a bunch of options for demonstration purposes.
    ;

    // Optional description of some or all of the flags (must match field names in the struct).
    pub const descriptions = .{
        .force = "Use the force",
    };

    force: bool, // Set to `true` only if '--force' is passed.

    // Subcommands can be defined through the `command` field, which should be a union with struct
    // fields which are defined the same way this struct is. Subcommands may be nested.
    // Subcommands (this union) can be made optional.
    command: ?union(enum) {
        frobnicate: struct {
            pub const descriptions = .{
                .level = "Frobnication level",
            };

            level: u8,

            positional: struct {
                trailing: []const []const u8,
            },
        },
        defrabulise: struct {
            supercharge: bool,
        },

        pub const descriptions = .{
            .frobnicate = "Frobnicate everywhere",
            .defrabulise = "Defrabulise everyone",
        };
    },

    // Optional declaration to define shorthands. These can be chained e.g '-fs large'.
    pub const switches = .{
        .force = 'f',
    };
};
