const std = @import("std");
const Io = std.Io;

const json_parser = @import("json_parser");

pub fn main(_: std.process.Init) !void {
}

// test "basic json string" {
//     var dba: std.heap.DebugAllocator(.{}) = .init;
//     defer std.debug.assert(dba.deinit() == .ok);
//     const allocator = dba.allocator();
//
//     const json =
//         \\{
//         \\  "a": "Hello World!",
//         \\  "b": 420,
//         \\  "c": 6.9,
//         \\  "d": {"e": true},
//         \\  "b": [1, 2, 3]
//         \\}
//     ;
//
//     const jsonNode: json_parser.JsonNode = try .parseFrom(allocator, json);
//
//     try std.testing.expect(switch (jsonNode.get("a").?) {
//         .string => |s| std.mem.eql(u8, s, "Hello World!"),
//         else => false,
//     });
//
// }
