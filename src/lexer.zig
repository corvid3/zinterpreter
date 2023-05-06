const std = @import("std");
const _diagnostics = @import("diagnostics.zig");
const Token = @import("Token.zig");

const Self = @This();

diagnostics: *_diagnostics.DiagnosticQueue,
str: []const u8,
idx: u64 = 0,

pub fn lex(alloc: std.mem.Allocator, diagnostics: *_diagnostics.DiagnosticQueue, str: []const u8) !std.MultiArrayList(Token) {
    var lexer = Self{ .str = str, .diagnostics = diagnostics };

    var toks = std.MultiArrayList(Token){};

    while (true) {
        var tok = lexer.lexOne() catch break;
        try toks.append(alloc, tok);
    }

    return toks;
}

inline fn nextChar(self: *Self) ?u8 {
    if (self.idx >= self.str.len) return null;
    var c = self.str[self.idx];
    self.idx += 1;
    return c;
}

inline fn peekChar(self: *Self) ?u8 {
    return if (self.idx >= self.str.len) null else self.str[self.idx];
}

inline fn simple(self: *Self, begin: u64, tag: Token.Tag) Token {
    const out = Token{ .tag = tag, .slice = self.str[begin..self.idx] };
    self.idx += 1;
    return out;
}

fn lexOne(self: *Self) error{ EOF, UnknownToken }!Token {
    while (std.ascii.isWhitespace(
        self.peekChar() orelse return error.EOF,
    )) self.idx += 1;

    const begin = self.idx;

    return switch (self.peekChar() orelse return error.EOF) {
        '+' => self.simple(begin, .Plus),
        else => {
            self.diagnostics.push_error(
                _diagnostics.Diagnostic{
                    .what = "Unknown symbol found in lexer",
                    .where = self.str[begin - 1 .. begin],
                },
            );

            return error.UnknownToken;
        },
    };
}
