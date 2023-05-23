const std = @import("std");
const Token = @import("Token.zig");

toks: std.MultiArrayList(Token),
nodes: std.MultiArrayList(Node) = .{},
extra_data: std.ArrayListUnmanaged(ExtraData) = .{},

/// a list of nodidx's which point to functiondefs in the node manifest
functions: std.ArrayListUnmanaged(u64) = .{},

pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
    self.toks.deinit(alloc);
    self.nodes.deinit(alloc);
    self.extra_data.deinit(alloc);
}

pub inline fn getTokTags(self: *const @This()) []const Token.Tag {
    return self.toks.items(.tag);
}

pub inline fn getTokSlice(self: *const @This()) []const []const u8 {
    return self.toks.items(.slice);
}

pub const Node = struct {
    tag: Tag,
    data: Data,

    pub const Tag = enum(u8) {
        Add,
        Sub,
        Mul,
        Div,

        Integer,
        Double,

        UnaryNegation,

        FunctionCall,
        FunctionDef,

        Return,
    };

    pub const Data = union {
        null: void,

        /// left + right point to indexes in the node list
        Binary: struct {
            left: u64,
            right: u64,
        },

        /// contains a nodeidx or a tokidx
        Unary: u64,

        /// points to an extra-data node in the Ast
        ExtraData: u64,
    };
};

pub const ExtraData = union {
    null: void,

    FunctionDef: FunctionDef,
    FunctionCall: FunctionCall,

    pub const FunctionDef = struct {
        name: []const u8,
        block: std.ArrayListUnmanaged(u64),
    };

    pub const FunctionCall = struct {
        name: []const u8,
        params: []const u64,
    };

    pub fn deinit(self: *ExtraData, alloc: std.mem.Allocator) void {
        switch (self) {
            .FunctionDef => {
                alloc.free(self.FunctionDef.block);
            },
        }
    }
};

/// prints an entire AST to a string, beautified
/// caller owns returned string
pub fn prettyPrint(alloc: std.mem.Allocator, ast: @This()) ![]u8 {
    var str = std.ArrayList(u8).init(alloc);
    var strw = str.writer();

    for (ast.functions.items) |fidx| {
        try prettyPrintInternal(strw, ast, fidx, 0);
    }

    return try str.toOwnedSlice();
}

fn prettyPrintInternal(str: std.ArrayList(u8).Writer, ast: @This(), fidx: u64, indent: u64) !void {
    // add an indent
    for (0..indent) |_| try std.fmt.format(str, "  ", .{});

    const nodetype = ast.nodes.items(.tag)[fidx];
    const nodedata = ast.nodes.items(.data)[fidx];

    switch (nodetype) {
        // literals
        Node.Tag.Integer => try std.fmt.format(
            str,
            "INTEGER = {s}\n",
            .{ast.getTokSlice()[nodedata.Unary]},
        ),

        Node.Tag.Double => try std.fmt.format(
            str,
            "DOUBLE = {s}\n",
            .{ast.getTokSlice()[nodedata.Unary]},
        ),

        Node.Tag.UnaryNegation => {},

        // binary operations
        Node.Tag.Add, Node.Tag.Sub, Node.Tag.Mul, Node.Tag.Div => {
            const ts = switch (nodetype) {
                .Add => "ADD",
                .Sub => "SUB",
                .Mul => "MUL",
                .Div => "DIV",
                else => unreachable,
            };

            try std.fmt.format(str, "{s}\n", .{ts});
            try prettyPrintInternal(str, ast, nodedata.Binary.left, indent + 1);
            try prettyPrintInternal(str, ast, nodedata.Binary.right, indent + 1);
        },

        Node.Tag.FunctionDef => {
            const ed: ExtraData = ast.extra_data.items[nodedata.Unary];

            try std.fmt.format(
                str,
                "FUNCTION: {s}\n",
                .{ed.FunctionDef.name},
            );

            for (ed.FunctionDef.block.items) |bidx|
                try prettyPrintInternal(str, ast, bidx, indent + 1);
        },

        Node.Tag.FunctionCall => {},

        Node.Tag.Return => {
            try std.fmt.format(str, "RETURN:\n", .{});
            try prettyPrintInternal(str, ast, nodedata.Unary, indent + 1);
        },
    }
}
