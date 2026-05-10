//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
pub const JsonTokenizer = @import("tokenizer.zig").JsonTokenizer;
pub const JsonParser = @import("parser.zig").JsonParser;

