const std = @import("std");
const Token = @import("Token.zig");
const Node = @import("Node.zig");
const _diagnostics = @import("diagnostics.zig");
const Diagnostic = _diagnostics.Diagnostic;

const Self = @This();

alloc: std.mem.Allocator,
tokens: std.MultiArrayList(Token),
idx: u64 = 0,

nodes: std.MultiArrayList(Node) = .{},

diagnostics: *_diagnostics.DiagnosticQueue,

const Error = error{Misparse};

fn pushNode(self: *Self, node: Node) u64 {
    self.nodes.append(self.alloc, node) catch std.debug.panic("memory error in pushNode", .{});
    return self.nodes.len - 1;
}

fn parseFactor(self: *Self) Error!u64 {
    const tag = self.tokens.items(.tag)[self.idx];

    self.idx += 1;

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
                    .where = self.tokens.items(.slice)[self.idx],
                },
            );

            return Error.Misparse;
        },
    }
}

fn parseTerm(self: *Self) Error!u64 {
    var left = try self.parseFactor();

    while (true) {
        const op = self.tokens.items(.tag)[self.idx];

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
        const op = self.tokens.items(.tag)[self.idx];

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

pub fn parse(
    alloc: std.mem.Allocator,
    diagnostics: *_diagnostics.DiagnosticQueue,
    tokens: std.MultiArrayList(Token),
) Error!std.MultiArrayList(Node) {
    var self = Self{
        .alloc = alloc,
        .tokens = tokens,
        .diagnostics = diagnostics,
    };

    _ = try self.parseExpr();

    for (self.nodes.items(.tag)) |*n| {
        std.debug.print("{?}\n", .{n});
    }

    return self.nodes;
}
