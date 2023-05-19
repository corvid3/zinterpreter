const std = @import("std");
const ir = @import("ir.zig");

const ConstantFoldingOptimizer = struct {
    // iterates through every block in the program, creating an exact copy except for wherever constants can be folded,
    // peforms the optimization, then replaces the corresponding original block with the new block
    const BlockLevelOptimizer = struct {
        alloc: std.mem.Allocator,
        program: *ir.Program,

        // the new block
        new_block: 

        fn optimize(self: *@This()) void {
            _ = self;
        }
    };

    // mutates program
    pub fn optimize(alloc: std.mem.Allocator, program: *ir.Program) void {
        _ = program;
        _ = alloc;
    }
};
