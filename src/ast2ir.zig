const std = @import("std");
const ir = @import("ir.zig");
const Ast = @import("Ast.zig");
const _diagnostics = @import("diagnostics.zig");

const FunctionTranslator = struct {
    alloc: std.mem.Allocator,
    ast: Ast,
    diagnostics: *_diagnostics.DiagnosticQueue,

    program: *ir.Program,
};

const BlockTranslator = struct {
    alloc: std.mem.Allocator,
    ast: *const Ast,
    diagnostics: *_diagnostics.DiagnosticQueue,

    program: *ir.Program,
    current_block: std.ArrayListUnmanaged(ir.Instruction) = .{},

    inline fn push_instr(self: *@This(), instr: ir.Instruction) void {
        self.current_block.append(
            self.alloc,
            instr,
        ) catch std.debug.panic("", .{});
    }

    fn translate_node(self: *@This(), nidx: u64) u64 {
        const node: Ast.Node.Tag = self.ast.nodes.items(.tag)[nidx];
        const node_data: Ast.Node.Data = self.ast.nodes.items(.data)[nidx];

        self.push_instr(switch (node) {
            .Integer => ir.Instruction{
                .tag = .Integer,
                .type = .Integer,
                .data = .{
                    .Integer = std.fmt.parseInt(
                        i64,
                        self.ast.getTokSlice()[node_data.Unary],
                        10,
                    ) catch std.debug.panic("", .{}),
                },
            },

            .Double => ir.Instruction{
                .tag = .Double,
                .type = .Double,
                .data = .{
                    .Double = std.fmt.parseFloat(
                        f64,
                        self.ast.getTokSlice()[node_data.Unary],
                    ) catch std.debug.panic("", .{}),
                },
            },

            .Add, .Sub, .Mul, .Div => |x| ir.Instruction{
                .tag = std.meta.stringToEnum(ir.Instruction.Tag, @tagName(x)) orelse std.debug.panic("", .{}),
                .type = .Undecided,
                .data = .{
                    .Binary = .{
                        .left = self.translate_node(node_data.Binary.left),
                        .right = self.translate_node(node_data.Binary.right),
                    },
                },
            },

            .UnaryNegation => ir.Instruction{
                .tag = .Negation,
                .type = .Undecided,
                .data = .{
                    .Unary = self.translate_node(node_data.Unary),
                },
            },

            // if on node that contains block,

            else => unreachable,
        });

        return self.current_block.items.len - 1;
    }

    // uses "blocks" array list to return the list of all irBlocks that this function generates
    fn translate(self: *@This(), func: Ast.ExtraData.FunctionDef, blocks: *std.ArrayListUnmanaged(ir.Block)) void {
        // create a block
        for (func.block.items) |nidx|
            _ = self.translate_node(nidx);

        // if this block does not end with either a branch or a return, append a void return instruction

        self.current_block.append(self.alloc, ir.Instruction{
            .tag = .Void,
            .type = .Void,
        }) catch std.debug.panic("", .{});

        self.current_block.append(self.alloc, ir.Instruction{
            .tag = .Return,
            .data = .{ .Unary = self.current_block.items.len - 1 },
            .type = .Undecided,
        }) catch std.debug.panic("", .{});

        blocks.append(
            self.alloc,
            self.current_block,
        ) catch std.debug.panic("", .{});
    }
};

pub fn translate_ast(alloc: std.mem.Allocator, ast: Ast, diagnostics: *_diagnostics.DiagnosticQueue) ir.Program {
    var program: ir.Program = ir.Program{};

    var self = BlockTranslator{
        .alloc = alloc,
        .diagnostics = diagnostics,
        .ast = &ast,
        .program = &program,
    };

    for (self.ast.functions.items) |fidx| {
        const func = self.ast.extra_data.items[fidx].FunctionDef;

        var blocks = std.ArrayListUnmanaged(ir.Block){};

        self.translate(func, &blocks);
        self.program.functions.append(
            self.alloc,
            ir.Function{ .name = func.name, .blocks = blocks },
        ) catch std.debug.panic("", .{});
    }

    return program;
}
