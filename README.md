## Simple Json Parser

Written as a little beginner project just to learn zig with a focus on the basic syntax and learning the memory and ownership model. The parser is not meant to be fully correct. No AI was used to write this.

Thoughts (mostly compared to Rust)
- Syntax is quite nice the inferred type `.` might be my favorite thing.
- Comptime still feels weird but I can tell with more practice it is strictly better than Rusts macro system.
- Needing to think about vtables for something as simple as allocator polymorphism is interesting.
- Error handling is a lot nicer out of the box than Rust, but Rust + anyhow still feels better (richer error contexts).
- I thought no string types would feel like more of a pain than it was (at least for this project).
- Zig's language server (ZLS) is quite poor. Especially compared to something like Rust Analyzer or Gopls.
