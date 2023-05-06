const std = @import("std");
const Token = @import("Token.zig");
const Node = @import("Node.zig");

const Self = @This();
// TODO: implement diagnostics

tokens: std.MultiArrayList(Token),
idx: u64,

nodes: std.MultiArrayList(Node),

fn parse_factor(self: *Self) u64 {
    switch (self.tokens.items(.tag)[self.idx]) {
        .Integer => {},
        .Double => {},

        else => 
    }
}

pub fn parse(tokens: std.MultiArrayList(Token)) !void {
    _ = tokens;
}
