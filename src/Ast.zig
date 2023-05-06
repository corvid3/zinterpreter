const std = @import("std");
const Token = @import("Token.zig");

toks: std.MultiArrayList(Token),
nodes: std.MultiArrayList(Node) = .{},
extra_data: std.ArrayListUnmanaged(ExtraData) = .{},

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
    };

    pub const Data = union {
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

pub const ExtraData = union(enum(u8)) {
    FunctionDef: struct {
        name: []const u8,

        block: []const u64,
    },

    pub fn deinit(self: *ExtraData, alloc: std.mem.Allocator) void {
        switch (self) {
            .FunctionDef => {
                alloc.free(self.FunctionDef.block);
            },
        }
    }
};
