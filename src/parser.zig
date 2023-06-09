// the design of the parser and AST layout is influenced by the
// zig codebase.

const std = @import("std");
const Token = @import("Token.zig");
const Ast = @import("Ast.zig");
const _diagnostics = @import("diagnostics.zig");
const Diagnostic = _diagnostics.Diagnostic;

const Node = Ast.Node;
const ExtraData = Ast.ExtraData;

const Self = @This();

alloc: std.mem.Allocator,
ast: Ast,
idx: u64 = 0,
diagnostics: *_diagnostics.DiagnosticQueue,

const Error = error{Misparse};

inline fn pushNode(self: *Self, node: Node) u64 {
    self.ast.nodes.append(
        self.alloc,
        node,
    ) catch std.debug.panic(
        "memory error in pushNode",
        .{},
    );
    return self.ast.nodes.len - 1;
}

inline fn pushNodeWithExtra(self: *Self, node: Node, ext: ExtraData) u64 {
    self.ast.extra_data.append(
        self.alloc,
        ext,
    ) catch std.debug.panic(
        "memory error in pushNodeWithExtra",
        .{},
    );

    return self.pushNode(node);
}

fn maybe(self: *Self, tag: Token.Tag, comptime move: bool) bool {
    const current = self.ast.getTokTags()[self.idx];
    if (current == tag) {
        if (move) self.idx += 1;
        return true;
    } else return false;
}

fn expect(self: *Self, tag: Token.Tag, comptime move: bool) !u64 {
    const current = self.ast.getTokTags()[self.idx];
    if (current != tag) {
        var str = std.ArrayListUnmanaged(u8){};

        std.fmt.format(
            str.writer(self.alloc),
            "Unexpected token <{?}>, when expecting <{?}>.",
            .{ current, tag },
        ) catch std.debug.panic("", .{});

        self.diagnostics.push_error(
            _diagnostics.Diagnostic{
                .what = str.toOwnedSlice(self.alloc) catch std.debug.panic("", .{}),
                .where = self.ast.getTokSlice()[self.idx],
            },
        );

        return error.Misparse;
    } else {
        const idx = self.idx;
        if (move) self.idx += 1;
        return idx;
    }
}

fn parseFactor(self: *Self) Error!u64 {
    const tag = self.ast.getTokTags()[self.idx];

    defer self.idx += 1;

    switch (tag) {
        .Integer => return self.pushNode(Node{
            .tag = Node.Tag.Integer,
            .data = Node.Data{ .Unary = self.idx },
        }),

        .Double => return self.pushNode(Node{
            .tag = Node.Tag.Double,
            .data = Node.Data{ .Unary = self.idx },
        }),

        .Minus => return self.pushNode(Node{
            .tag = Node.Tag.UnaryNegation,
            .data = Node.Data{
                .Unary = try self.parseFactor(),
            },
        }),

        else => {
            self.diagnostics.push_error(
                Diagnostic{
                    .what = "Unknown token when trying to parse a factor.",
                    .where = self.ast.getTokSlice()[self.idx],
                },
            );

            return Error.Misparse;
        },
    }
}

fn parseTerm(self: *Self) Error!u64 {
    var left = try self.parseFactor();

    while (true) {
        const op = self.ast.getTokTags()[self.idx];

        if (op != .Asterisk and op != .Solidus) break;

        // skip the operator token now
        self.idx += 1;

        const right = try self.parseFactor();

        var tag = if (op == .Asterisk) Node.Tag.Mul else Node.Tag.Div;

        left = self.pushNode(Node{
            .tag = tag,
            .data = Node.Data{
                .Binary = .{
                    .left = left,
                    .right = right,
                },
            },
        });
    }

    return left;
}

fn parseExpr(self: *Self) Error!u64 {
    var left = try self.parseTerm();

    while (true) {
        const op = self.ast.getTokTags()[self.idx];

        if (op != .Plus and op != .Minus) break;

        // skip the operator token now
        self.idx += 1;

        const right = try self.parseTerm();

        var tag = if (op == .Plus) Node.Tag.Add else Node.Tag.Sub;

        left = self.pushNode(Node{
            .tag = tag,
            .data = Node.Data{
                .Binary = .{
                    .left = left,
                    .right = right,
                },
            },
        });
    }

    return left;
}

fn parseExprOrStatement(self: *Self) Error!u64 {
    std.debug.print("TEST: {any}\n", .{self.ast.getTokTags()[self.idx]});
    if (self.maybe(.Return, true)) {
        return self.pushNode(Node{ .tag = .Return, .data = .{ .Unary = try self.parseExpr() } });
    } else {
        return self.parseExpr();
    }
}

fn parseBlock(self: *Self) Error!std.ArrayListUnmanaged(u64) {
    const blockDepth = self.ast.getTokSlice()[
        try self.expect(
            .Whitespace,
            true,
        )
    ].len;

    var blocknodes = std.ArrayListUnmanaged(u64){};

    while (true) {
        blocknodes.append(
            self.alloc,
            try self.parseExprOrStatement(),
        ) catch std.debug.panic("memory error in blocknodes, at parseBlock", .{});

        if (self.ast.getTokTags()[self.idx] == .EOF) break;

        const nextBlockDepth = self.ast.getTokSlice()[
            try self.expect(
                .Whitespace,
                false,
            )
        ].len;

        if (nextBlockDepth != blockDepth) break else self.idx += 1;
    }

    return blocknodes;
}

pub fn parse(
    alloc: std.mem.Allocator,
    diagnostics: *_diagnostics.DiagnosticQueue,
    tokens: std.MultiArrayList(Token),
) Error!Ast {
    var self = Self{
        .alloc = alloc,
        .diagnostics = diagnostics,
        .ast = Ast{
            .toks = tokens,
        },
    };

    // reserve a special entry node, at idx 0
    _ = self.pushNode(Node{ .tag = .Add, .data = .{ .null = {} } });
    const block = try self.parseBlock();
    self.ast.nodes.items(.tag)[0] = .FunctionDef;

    self.ast.extra_data.append(
        self.alloc,
        ExtraData{ .FunctionDef = .{
            .name = "main",
            .block = block,
        } },
    ) catch std.debug.panic("", .{});

    self.ast.nodes.items(.data)[0] = .{ .Unary = self.ast.extra_data.items.len - 1 };

    // temp. push 0 as the "main" function
    self.ast.functions.append(self.alloc, 0) catch std.debug.panic("", .{});

    for (self.ast.nodes.items(.tag)) |*n| {
        std.debug.print("{?}\n", .{n});
    }

    return self.ast;
}
