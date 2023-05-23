const std = @import("std");
const _diagnostics = @import("diagnostics.zig");
const Token = @import("Token.zig");

const Self = @This();

diagnostics: *_diagnostics.DiagnosticQueue,
begin: u64 = 0,
str: []const u8,
idx: u64 = 0,

pub fn lex(alloc: std.mem.Allocator, diagnostics: *_diagnostics.DiagnosticQueue, str: []const u8) !std.MultiArrayList(Token) {
    var lexer = Self{ .str = str, .diagnostics = diagnostics };

    var toks = std.MultiArrayList(Token){};

    // push a 1-level whitespace token into the queue
    // (1-level is the lowest whitespace token)
    try toks.append(alloc, Token{ .tag = .Whitespace, .slice = str[0..1] });

    while (true) {
        var tok = lexer.lexOne() catch break;
        try toks.append(alloc, tok);
    }

    try toks.append(alloc, Token{ .tag = .EOF, .slice = str[str.len..str.len] });

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

inline fn rtok(self: *Self, tag: Token.Tag) Token {
    const out = Token{ .tag = tag, .slice = self.str[self.begin .. self.idx + 1] };
    self.idx += 1;
    return out;
}

fn lexOne(self: *Self) error{ EOF, UnknownToken, Err }!Token {
    if ((self.peekChar() orelse return error.EOF) == '\n') {
        while ((self.peekChar() orelse 0x00) == ' ') : (_ = self.nextChar()) {}

        // another dumb hack
        self.begin += 1;

        return self.rtok(.Whitespace);
    }

    while (std.ascii.isWhitespace(
        self.peekChar() orelse return error.EOF,
    )) self.idx += 1;

    self.begin = self.idx;

    return switch (self.peekChar() orelse return error.EOF) {
        '+' => self.rtok(.Plus),
        '-' => self.rtok(.Minus),
        '*' => self.rtok(.Asterisk),
        '/' => self.rtok(.Solidus),
        '(' => self.rtok(.LeftParanthesis),
        ')' => self.rtok(.RightParanthesis),

        else => |c| {
            if (std.ascii.isDigit(c)) {
                while (true) {
                    const c2 = self.peekChar() orelse break;

                    if (!std.ascii.isDigit(c2) and c2 != '.') break;

                    self.idx += 1;
                }

                // dumb hack (see self.rtok)
                self.idx -= 1;

                const slice = self.str[self.begin..self.idx];
                const dec_count = std.mem.count(u8, slice, ".");
                if (dec_count == 0)
                    return self.rtok(.Integer)
                else if (dec_count == 1)
                    return self.rtok(.Double)
                else {
                    self.diagnostics.push_error(
                        _diagnostics.Diagnostic{ .what = "More than one decimal point in a number", .where = self.str[self.begin..self.idx] },
                    );

                    return error.Err;
                }
            } else if (std.ascii.isAlphabetic(c)) {
                while (true) {
                    const c2 = self.peekChar() orelse break;
                    if (!std.ascii.isAlphanumeric(c2)) break;
                    self.idx += 1;
                }

                const slice = self.str[self.begin..self.idx];

                // std.debug.print("TOKEN: {s}\n", .{slice});

                if (std.mem.eql(u8, slice, "return"))
                    return self.rtok(.Return)
                else
                    return self.rtok(.Identifier);
            } else {
                self.diagnostics.push_error(
                    _diagnostics.Diagnostic{
                        .what = "Unknown symbol found in lexer",
                        .where = self.str[self.begin - 1 .. self.idx],
                    },
                );

                return error.UnknownToken;
            }
        },
    };
}
