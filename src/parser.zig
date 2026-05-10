const std = @import("std");
const tok = @import("tokenizer.zig");

const JsonParseError = error{
    UnexpectedToken,
} || tok.JsonTokenizerError || std.mem.Allocator.Error;

pub const JsonParser = struct {
    allocator: std.mem.Allocator,
    tokenizer: tok.JsonTokenizer,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, str: []const u8) JsonParser {
        return Self{ .allocator = allocator, .tokenizer = .init(str) };
    }

    pub fn initFromTokenizer(allocator: std.mem.Allocator, tokenizer: tok.JsonTokenizer) JsonParser {
        return Self{ .allocator = allocator, .tokenizer = tokenizer };
    }

    pub fn parse(self: *Self) JsonParseError!JsonValue {
        return try self.parseValue();
    }

    fn expect(self: *Self, expected_tag: tok.JsonTokenTag) JsonParseError!tok.JsonToken {
        const next_token = try self.tokenizer.next();
        const active_tag = std.meta.activeTag(next_token);
        if (expected_tag != active_tag) {
            return error.UnexpectedToken;
        }
        return next_token;
    }

    fn parseValue(self: *Self) JsonParseError!JsonValue {
        switch (try self.tokenizer.peek()) {
            .l_brace => return try self.parseObject(),
            .l_bracket => return try self.parseArray(),
            .string => return try self.parseString(),
            .number => return try self.parseNumber(),
            .true, .false, .null => return try self.parseKeyword(),
            else => return error.UnexpectedToken,
        }
    }

    fn parseObject(self: *Self) JsonParseError!JsonValue {
        _ = try self.expect(.l_brace);
        var map: std.StringHashMap(JsonValue) = .init(self.allocator);
        errdefer {
            var it = map.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
            }
            map.deinit();
        }

        while (true) {
            switch (try self.tokenizer.next()) {
                .r_brace => return .{ .object = map },
                .string => |s| {
                    _ = try self.expect(.colon);
                    const val = try self.parseValue();
                    try map.put(s, val);
                    if (try self.tokenizer.peek() == .comma) {
                        _ = try self.tokenizer.next();
                        continue;
                    }
                    break;
                },
                else => {
                    return error.UnexpectedToken;
                },
            }
        }
        _ = try self.expect(.r_brace);
        return .{ .object = map };
    }
    fn parseArray(self: *Self) JsonParseError!JsonValue {
        _ = try self.expect(.l_bracket);
        var list: std.ArrayList(JsonValue) = try .initCapacity(self.allocator, 0);
        errdefer {
            for (list.items) |*v| {
                v.deinit(self.allocator);
            }
            list.deinit(self.allocator);
        }

        while (true) {
            switch (try self.tokenizer.peek()) {
                .r_bracket => {
                    _ = try self.tokenizer.next();
                    return .{ .array = list };
                },
                else => {
                    try list.append(self.allocator, try self.parseValue());
                    if (try self.tokenizer.peek() == .comma) {
                        _ = try self.tokenizer.next();
                        continue;
                    }
                    break;
                },
            }
        }
        _ = try self.expect(.r_bracket);
        return .{ .array = list };
    }
    fn parseString(self: *Self) JsonParseError!JsonValue {
        const token = try self.expect(.string);
        return .{ .string = token.string };
    }
    fn parseNumber(self: *Self) JsonParseError!JsonValue {
        const token = try self.expect(.number);
        if (std.mem.findScalar(u8, token.number, '.') != null) {
            return .{ .float = std.fmt.parseFloat(f64, token.number) catch return error.UnexpectedToken };
        } else {
            return .{ .int = std.fmt.parseInt(i64, token.number, 10) catch return error.UnexpectedToken };
        }
    }
    fn parseKeyword(self: *Self) JsonParseError!JsonValue {
        const token = try self.tokenizer.next();
        return switch (token) {
            .null => .null,
            .true => .{ .bool = true },
            .false => .{ .bool = false },
            else => error.UnexpectedToken,
        };
    }
};

pub const JsonValue = union(enum) {
    null,
    bool: bool,
    int: i64,
    float: f64,
    string: []const u8, //borrowed
    array: std.ArrayList(JsonValue), //owned
    object: std.StringHashMap(JsonValue), //owned

    const Self = @This();

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .array => |*a| {
                for (a.items) |*v| {
                    v.deinit(allocator);
                }
                a.deinit(allocator);
            },
            .object => |*o| {
                var it = o.iterator();
                while (it.next()) |entry| {
                    entry.value_ptr.deinit(allocator);
                }
                o.deinit();
            },
            else => {},
        }
    }
};

test "json parser simple test" {
    const allocator = std.testing.allocator;

    const input =
        \\ {
        \\ "hello": "world",
        \\ "key": [true, false],
        \\ "number": 52,
        \\ "none": null
        \\ }
    ;
    const tokenizer: tok.JsonTokenizer = .init(input);
    var parser: JsonParser = .initFromTokenizer(allocator, tokenizer);

    var root = try parser.parse();
    defer root.deinit(allocator);

    try std.testing.expectEqual(@as(std.meta.Tag(JsonValue), .object), std.meta.activeTag(root));

    const obj = root.object;

    const hello = obj.get("hello") orelse return error.TestExpectedEqual;
    try std.testing.expectEqual(@as(std.meta.Tag(JsonValue), .string), std.meta.activeTag(hello));
    try std.testing.expectEqualStrings("world", hello.string);

    const none = obj.get("none") orelse return error.TestExpectedEqual;
    try std.testing.expectEqual(@as(std.meta.Tag(JsonValue), .null), std.meta.activeTag(none));
}
