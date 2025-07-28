# flags

An effortless command-line argument parser for Zig.

Simply declare a struct and flags will inspect the fields at compile-time to determine how arguments are parsed:

```zig
pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    defer _ = debug_allocator.deinit();
    const gpa = debug_allocator.allocator();

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    const cli = flags.parse(
        args,
        "my-program",

        struct {
            username: []const u8,
        },

        .{},
    );

    try std.io.getStdOut().writer().print("Hello, {s}!\n", .{cli.username});
}

const std = @import("std");
const flags = @import("flags");
```

## Features

- Zero allocations.
- Cross platform.
- Single-function, declarative API.
- Multi-level subcommands.
- Automatic help message generation at comptime.
- Customisable terminal coloring.

## Getting Started

flags is intended to be used with the latest Zig release. If flags is out of date, please open an issue.

To import flags to your project, run the following command:

```
zig fetch --save git+https://github.com/joegm/flags
```

Then set up the dependency in your `build.zig`:

```zig
    const flags_dep = b.dependency("flags", .{
        .target = target,
        .optimize = optimize,
    })

    exe.root_module.addImport("flags", flags_dep.module("flags"));
```

See the [examples](examples/) for basic usage.
