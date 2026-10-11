const std = @import("std");

pub const FlagsInfo = struct {
    flags: []const Flag = &.{},
    positionals: []const Positional = &.{},
    subcommands: []const SubCommand = &.{},
    optional_commands: bool = false,
};

const SubCommand = struct {
    /// A nested Flags struct.
    type: type,
    field_name: []const u8,
    command_name: []const u8,
};

pub const Flag = struct {
    type: type,
    default_value: ?*const anyopaque,
    field_name: []const u8,
    /// For field_name == "my_flag" -> flag_name == "--my-flag".
    flag_name: []const u8,
    switch_char: ?u8,

    pub fn isOptional(flag: Flag) bool {
        return flag.type == bool or
            @typeInfo(flag.type) == .optional or
            flag.default_value != null;
    }
};

pub const Positional = struct {
    type: type,
    default_value: ?*const anyopaque,
    field_name: []const u8,
    /// The placeholder name, e.g `<FILE>`
    arg_name: []const u8,

    pub fn isOptional(positional: Positional) bool {
        return @typeInfo(positional.type) == .optional or
            positional.default_value != null;
    }
};

pub fn info(comptime Flags: type) FlagsInfo {
    std.debug.assert(@inComptime());
    if (@typeInfo(Flags) != .@"struct") {
        compileError("input type is not a struct: {s}", .{@typeName(Flags)});
    }

    var command = FlagsInfo{};

    const switches = getSwitches(Flags);

    const sinfo = @typeInfo(Flags).@"struct";
    for (sinfo.field_types, sinfo.field_names) |field_type, field_name| {
        if (std.mem.eql(u8, field_name, "positional")) {
            if (@typeInfo(field_type) != .@"struct") compileError(
                "'positional' field is not a struct type: {s}",
                .{@typeName(field_type)},
            );

            var seen_optional = false;
            const pinfo = @typeInfo(field_type).@"struct";
            for (pinfo.field_types, pinfo.field_names) |positional_type, positional_name| {
                if (std.mem.eql(u8, positional_name, "trailing")) {
                    continue;
                }
                if (@typeInfo(positional_type) != .optional) {
                    if (seen_optional) compileError(
                        "non-optional positional field after optional: {s}",
                        .{positional_name},
                    );
                } else {
                    seen_optional = true;
                }
                command.positionals = command.positionals ++ .{Positional{
                    .type = positional_type,
                    .default_value = null, // positional.default_value_ptr,
                    .field_name = positional_name,
                    .arg_name = positionalName(positional_name),
                }};
            }
        } else if (std.mem.eql(u8, field_name, "command")) {
            const cmd_type = @typeInfo(field_type);
            switch (cmd_type) {
                .@"union" => {},
                .optional => |o| {
                    const opt_cmd_type = @typeInfo(o.child);
                    if (opt_cmd_type != .@"union") compileError(
                        "command field type is not a union: {s}",
                        .{@typeName(field_type)},
                    );
                    command.optional_commands = true;
                },
                else => compileError(
                    "command field type is not a union: {s}",
                    .{@typeName(field_type)},
                ),
            }
            const u = @typeInfo(unwrapOptional(field_type)).@"union";
            for (u.field_types, u.field_names) |ucmd_type, ucmd_name| {
                command.subcommands = command.subcommands ++ .{SubCommand{
                    .type = ucmd_type,
                    .field_name = ucmd_name,
                    .command_name = toKebab(ucmd_name),
                }};
            }
        } else {
            command.flags = command.flags ++ .{Flag{
                .type = field_type,
                // TODO
                .default_value = null, // field.default_value_ptr,
                .field_name = field_name,
                .flag_name = "--" ++ toKebab(field_name),
                .switch_char = @field(switches, field_name),
            }};
        }
    }

    return command;
}

pub fn hasTrailingField(Flags: type) bool {
    return @hasField(Flags, "positional") and
        @hasField(@FieldType(Flags, "positional"), "trailing");
}

// A struct with fields identical to T except every field type is ?F and the default value is null.
fn FieldAttr(T: type, F: type) type {
    return std.enums.EnumFieldStruct(std.meta.FieldEnum(T), ?F, @as(?F, null));
}

fn getSwitches(T: type) FieldAttr(T, u8) {
    var switches: FieldAttr(T, u8) = .{};

    if (!@hasDecl(T, "switches")) {
        return switches;
    }

    const Switches = @TypeOf(T.switches);
    if (@typeInfo(Switches) != .@"struct") {
        compileError("switches is not a struct value: {s}", .{@typeName(Switches)});
    }

    const struct_info = @typeInfo(Switches).@"struct";
    inline for (struct_info.field_names, 0..) |field_name, field_index| {
        if (!@hasField(T, field_name)) {
            compileError("switch name does not match any field: {s}", .{field_name});
        }

        const switch_val = @field(T.switches, field_name);
        if (@TypeOf(switch_val) != comptime_int) {
            compileError("switch value is not a character: {any}", .{switch_val});
        }
        const switch_char = std.math.cast(u8, switch_val) orelse {
            compileError("switch value is not a character: {any}", .{switch_val});
        };
        if (!std.ascii.isAlphanumeric(switch_char)) {
            compileError("switch character is not a letter or digit: {c}", .{switch_char});
        }

        for (struct_info.field_names[field_index + 1 ..]) |other_field| {
            const other_val = @field(T.switches, other_field);
            if (switch_val == other_val) compileError(
                "duplicate switch values: {s} and {s}",
                .{ field_name, other_field },
            );
        }

        @field(switches, field_name) = switch_char;
    }

    return switches;
}

pub fn getDescriptions(T: type) FieldAttr(T, []const u8) {
    var descriptions: FieldAttr(T, []const u8) = .{};

    if (!@hasDecl(T, "descriptions")) {
        return descriptions;
    }

    const D = @TypeOf(T.descriptions);
    if (@typeInfo(D) != .@"struct") {
        compileError("descriptions is not a struct value: {s}", .{@typeName(D)});
    }

    for (@typeInfo(D).@"struct".field_names) |field_name| {
        if (!@hasField(T, field_name)) {
            compileError("description name does not match any field: '{s}'", .{field_name});
        }

        const description = @field(T.descriptions, field_name);
        @field(descriptions, field_name) =
            @as([]const u8, description); // description must be a string
    }

    return descriptions;
}

pub fn getFormats(T: type) FieldAttr(T, []const u8) {
    var formats: FieldAttr(T, []const u8) = .{};
    if (!@hasDecl(T, "formats")) {
        return formats;
    }

    const F = @TypeOf(T.formats);
    if (@typeInfo(F) != .@"struct") {
        compileError("formats is not a struct value: {s}", .{@typeName(F)});
    }

    for (@typeInfo(F).@"struct".field_names) |field_name| {
        if (!@hasField(T, field_name)) {
            compileError("format name does not match any field: {s}", .{field_name});
        }

        const format = @field(T.formats, field_name);
        @field(formats, field_name) =
            @as([]const u8, format); // format must be a string
    }

    return formats;
}

pub fn compileError(comptime fmt: []const u8, args: anytype) void {
    @compileError("(flags) " ++ std.fmt.comptimePrint(fmt, args));
}

pub fn unwrapOptional(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .optional => |opt| opt.child,
        else => T,
    };
}

/// Casts the opaque default_value, if it exists, to a Flag/Positional's actual type.
pub fn defaultValue(comptime option: anytype) ?option.type {
    const default_opaque = option.default_value orelse return null;
    const default: *const option.type = @ptrCast(@alignCast(default_opaque));
    return default.*;
}

/// Converts "positional_field" to "<POSITIONAL_FIELD>.".
pub fn positionalName(comptime field_name: []const u8) []const u8 {
    comptime var upper: []const u8 = &.{};
    comptime for (field_name) |c| {
        upper = upper ++ .{std.ascii.toUpper(c)};
    };
    return std.fmt.comptimePrint("<{s}>", .{upper});
}

/// Converts from snake_case to kebab-case at comptime.
pub fn toKebab(comptime string: []const u8) []const u8 {
    comptime var name: []const u8 = "";

    inline for (string) |ch| name = name ++ .{switch (ch) {
        '_' => '-',
        else => ch,
    }};

    return name;
}
