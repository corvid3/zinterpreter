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

const Error = error{Misparse} | error.OutOfMemory;

fn pushNode(self: *Self, node: Node) Error!u64 {
    try self.nodes.append(self.alloc, node);
    return self.nodes.len - 1;
}

fn parseFactor(self: *Self) Error!u64 {
    defer self.idx += 1;

    switch (self.tokens.items(.tag)[self.idx]) {
        .Integer => return self.pushNode(Node{
            .tag = Node.Tag.Integer,
            .data = Node.Data{
                .Integer = std.fmt.parseInt(
                    i64,
                    self.tokens.items(.slice)[self.idx] catch std.debug.panic("", .{}),
                    10,
                ),
            },
        }),

        .Double => return self.pushNode(Node{
            .tag = Node.Tag.Double,
            .data = Node.Data{
                .Double = std.fmt.parseFloat(
                    f64,
                    self.tokens.items(.slice)[self.idx] catch std.debug.panic("", .{}),
                ),
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

    try self.parseFactor();

    for (self.nodes.slice()) |*n| {
        std.debug.print("{?}", .{n.tag});
    }
}
