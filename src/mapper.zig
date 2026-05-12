const std = @import("std");
const parser = @import("parser.zig");

pub fn ObjectMapper(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const init: Self = .{};

        pub fn readJsonMap(self: *const Self, map: std.StringHashMap(parser.JsonValue)) !T {
            var result: T = undefined;
            _ = self;
            inline for (std.meta.fields(T)) |field| {
                const field_name = field.name;
                const val = map.get(field_name) orelse return error.MissingField;
                @field(result, field_name) = try Self.convert(field.type, val);
            }
            return result;
        }

        fn fromObject(comptime FieldType: type, obj: std.StringHashMap(parser.JsonValue)) !FieldType {
            var result: FieldType = undefined;
            inline for (std.meta.fields(FieldType)) |field| {
                const raw = obj.get(field.name) orelse return error.MissingField;
                @field(result, field.name) = try convert(field.type, raw);
            }
            return result;
        }

        fn convert(comptime FieldType: type, value: parser.JsonValue) !FieldType {
            return switch (@typeInfo(FieldType)) {
                .bool => switch (value) {
                    .bool => |b| b,
                    else => error.TypeMismatch,
                },
                .int => switch (value) {
                    .int => |n| std.math.cast(FieldType, n) orelse error.TypeMismatch,
                    else => error.TypeMismatch,
                },
                .float => switch (value) {
                    .float => |f| @as(FieldType, @floatCast(f)),
                    .int => |n| @as(FieldType, @floatFromInt(n)),
                    else => error.TypeMismatch,
                },
                .pointer => |ptr| blk: {
                    // []const u8
                    if (ptr.size == .slice and ptr.child == u8 and ptr.is_const) {
                        break :blk switch (value) {
                            .string => |s| s,
                            else => error.TypeMismatch,
                        };
                    }
                    return error.UnsupportedType;
                },
                .optional => |opt| switch (value) {
                    .null => null,
                    else => try Self.convert(opt.child, value),
                },
                .@"struct" => switch (value) {
                    .object => |obj| try Self.fromObject(FieldType, obj),
                    else => error.TypeMismatch,
                },
                else => error.UnsupportedType,
            };
        }
    };
}

test "object mapper reads flat struct" {
    const User = struct {
        name: []const u8,
        age: i64,
        active: bool,
    };

    var map: std.StringHashMap(parser.JsonValue) = .init(std.testing.allocator);
    defer map.deinit();

    try map.put("name", .{ .string = "kaleb" });
    try map.put("age", .{ .int = 42 });
    try map.put("active", .{ .bool = true });

    const mapper = ObjectMapper(User).init;

    const user = try mapper.readJsonMap(map);
    try std.testing.expectEqualStrings("kaleb", user.name);
    try std.testing.expectEqual(@as(i64, 42), user.age);
    try std.testing.expectEqual(true, user.active);
}
