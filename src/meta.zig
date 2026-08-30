const std = @import("std");

pub const FlagsInfo = struct {
    flags: []const Flag = &.{},
    positionals: []const Positional = &.{},
    subcommands: []const SubCommand = &.{},
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

    const FlagsTypeInfo = @typeInfo(Flags).@"struct";
    for (0..FlagsTypeInfo.field_names.len) |field_index| {
        const field_name = FlagsTypeInfo.field_names[field_index];
        const field_type = FlagsTypeInfo.field_types[field_index];
        const field_attrs = FlagsTypeInfo.field_attrs[field_index];

        if (std.mem.eql(u8, field_name, "positional")) {
            if (@typeInfo(field_type) != .@"struct") compileError(
                "'positional' field is not a struct type: {s}",
                .{@typeName(field_type)},
            );

            const PosTypeInfo = @typeInfo(field_type).@"struct";
            var seen_optional = false;
            for (0..PosTypeInfo.field_names.len) |positional_index| {
                const positional_name = PosTypeInfo.field_names[positional_index];
                const positional_type = PosTypeInfo.field_types[positional_index];
                const positional_attrs = PosTypeInfo.field_attrs[positional_index];
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
                    .default_value = positional_attrs.default_value_ptr,
                    .field_name = positional_name,
                    .arg_name = positionalName(positional_name),
                }};
            }
        } else if (std.mem.eql(u8, field_name, "command")) {
            if (@typeInfo(field_type) != .@"union") compileError(
                "command field type is not a union: {s}",
                .{@typeName(field_type)},
            );

            const UnionTypeInfo = @typeInfo(field_type).@"union";
            for (0..UnionTypeInfo.field_names.len) |cmd_index| {
                command.subcommands = command.subcommands ++ .{SubCommand{
                    .type = UnionTypeInfo.field_types[cmd_index],
                    .field_name = UnionTypeInfo.field_names[cmd_index],
                    .command_name = toKebab(UnionTypeInfo.field_names[cmd_index]),
                }};
            }
        } else {
            command.flags = command.flags ++ .{Flag{
                .type = field_type,
                .default_value = field_attrs.default_value_ptr,
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

    const SwitchTypeInfo = @typeInfo(Switches).@"struct";
    for (0..SwitchTypeInfo.field_names.len) |field_index| {
        const switch_field = SwitchTypeInfo.field_names[field_index];
        if (!@hasField(T, switch_field)) {
            compileError("switch name does not match any field: {s}", .{switch_field});
        }

        const switch_val = @field(T.switches, switch_field);
        if (@TypeOf(switch_val) != comptime_int) {
            compileError("switch value is not a character: {any}", .{switch_val});
        }
        const switch_char = std.math.cast(u8, switch_val) orelse {
            compileError("switch value is not a character: {any}", .{switch_val});
        };
        if (!std.ascii.isAlphanumeric(switch_char)) {
            compileError("switch character is not a letter or digit: {c}", .{switch_char});
        }

        for (SwitchTypeInfo.field_names[field_index + 1 ..]) |other_field| {
            const other_val = @field(T.switches, other_field);
            if (switch_val == other_val) compileError(
                "duplicate switch values: {s} and {s}",
                .{ switch_field, other_field },
            );
        }

        @field(switches, switch_field) = switch_char;
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

    const DTypeInfo = @typeInfo(D).@"struct";
    for (0..DTypeInfo.field_names.len) |field_index| {
        const field_name = DTypeInfo.field_names[field_index];
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

    const FTypeInfo = @typeInfo(F).@"struct";
    for (0..FTypeInfo.field_names.len) |field_index| {
        const field_name = FTypeInfo.field_names[field_index];
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
