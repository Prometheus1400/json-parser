const std = @import("std");

pub const JsonToken = union(enum) {
    l_brace,
    r_brace,
    l_bracket,
    r_bracket,
    colon,
    comma,
    true,
    false,
    null,
    eof,
    string: []const u8,
    number: []const u8,
};

pub const JsonTokenTag = std.meta.Tag(JsonToken);

pub const JsonTokenizerError = error{
    UnterminatedString,
    UnexpectedCharacter,
    UnexpectedEOF,
};

pub const JsonTokenizer = struct {
    i: u64 = 0,
    str: []const u8,
    cache: ?JsonToken,

    const Self = @This();

    pub fn init(str: []const u8) Self {
        return Self{ .i = 0, .str = str, .cache = null };
    }

    fn peek_char(self: *const Self) ?u8 {
        if (self.i >= self.str.len) {
            return null;
        }
        return self.str[self.i];
    }

    fn consumed(self: *const Self) bool {
        return self.i >= self.str.len;
    }

    fn has_remaining(self: *const Self, remaining: u64) bool {
        return self.str.len - self.i >= remaining;
    }

    pub fn peek(self: *Self) JsonTokenizerError!JsonToken {
        if (self.cache) |tok| {
            return tok;
        }
        self.cache = try self.next();
        return self.cache.?;
    }

    pub fn next(self: *Self) JsonTokenizerError!JsonToken {
        if (self.cache) |tok| {
            self.cache = null;
            return tok;
        }
        self.skip_whitespace();
        const token: JsonToken = switch (self.peek_char() orelse return .eof) {
            '{' => .l_brace,
            '}' => .r_brace,
            '[' => .l_bracket,
            ']' => .r_bracket,
            ':' => .colon,
            ',' => .comma,
            '"' => try self.readString(),
            't', 'f', 'n' => try self.readKeyword(),
            '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => try self.readNumber(),
            else => {
                return error.UnexpectedCharacter;
            },
        };
        switch (token) {
            .l_brace,
            .r_brace,
            .l_bracket,
            .r_bracket,
            .colon,
            .comma,
            => {
                self.i += 1;
            },
            else => {},
        }
        return token;
    }

    fn skip_whitespace(self: *Self) void {
        while (self.i < self.str.len) {
            switch (self.str[self.i]) {
                ' ', '\t', '\n' => {
                    self.i += 1;
                },
                else => break,
            }
        }
    }

    fn readString(self: *Self) JsonTokenizerError!JsonToken {
        const old_i = self.i;
        self.i += 1;
        while (!self.consumed() and (self.peek_char() orelse return error.UnexpectedEOF) != '"') {
            self.i += 1;
        }
        if (self.consumed()) {
            return error.UnterminatedString;
        }
        if (self.i - old_i < 2) {
            return .{ .string = "" };
        }
        self.i += 1;
        return .{ .string = self.str[old_i + 1 .. self.i - 1] };
    }

    fn readKeyword(self: *Self) JsonTokenizerError!JsonToken {
        switch (self.peek_char() orelse return error.UnexpectedEOF) {
            't', 'n' => {
                if (!self.has_remaining(4)) {
                    return error.UnexpectedCharacter;
                }
                if (std.mem.eql(u8, "true", self.str[self.i .. self.i + 4])) {
                    self.i += 4;
                    return .true;
                }
                if (std.mem.eql(u8, "null", self.str[self.i .. self.i + 4])) {
                    self.i += 4;
                    return .null;
                }
            },
            'f' => {
                if (!self.has_remaining(5)) {
                    return error.UnexpectedCharacter;
                } else if (std.mem.eql(u8, "false", self.str[self.i .. self.i + 5])) {
                    self.i += 5;
                    return .false;
                }
            },
            else => return error.UnexpectedCharacter,
        }
        return error.UnexpectedCharacter;
    }
    fn readNumber(self: *Self) JsonTokenizerError!JsonToken {
        const old_i = self.i;
        while (true) {
            switch (self.peek_char() orelse return error.UnexpectedEOF) {
                '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => self.i += 1,
                '.' => {
                    self.i += 1;
                    break;
                },
                else => {
                    return .{ .number = self.str[old_i..self.i] };
                },
            }
        }
        if (!std.mem.containsAtLeastScalar2(u8, "0123456789", self.peek_char() orelse return error.UnexpectedEOF, 1)) {
            return error.UnexpectedCharacter;
        }
        while (true) {
            switch (self.peek_char() orelse return error.UnexpectedEOF) {
                '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => self.i += 1,
                else => {
                    return .{ .number = self.str[old_i..self.i] };
                },
            }
        }
    }
};

test "json tokenizer simple test" {
    const input =
        \\ {
        \\ "hello": "world",
        \\ "key": [true, false],
        \\ "number": 52,
        \\ "none": null
        \\ }
    ;
    const expected = [_]JsonToken{
        .l_brace,
        .{ .string = "hello" },
        .colon,
        .{ .string = "world" },
        .comma,
        .{ .string = "key" },
        .colon,
        .l_bracket,
        .true,
        .comma,
        .false,
        .r_bracket,
        .comma,
        .{ .string = "number" },
        .colon,
        .{ .number = "52" },
        .comma,
        .{ .string = "none" },
        .colon,
        .null,
        .r_brace,
        .eof,
    };
    var i: u64 = 0;
    var tokenizer: JsonTokenizer = .init(input);
    while (i < expected.len) {
        const actual_token = try tokenizer.next();
        const expected_token = expected[i];
        try std.testing.expectEqual(std.meta.activeTag(expected_token), std.meta.activeTag(actual_token));
        i += 1;
    }

    try std.testing.expectEqual(expected.len, i);
}
