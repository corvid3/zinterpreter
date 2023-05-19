const std = @import("std");
const ir = @import("ir.zig");
const vm = @import("vm.zig");

const FunctionTranslator = struct {
    alloc: std.mem.Allocator,
    program: ir.Program,

    stream: std.ArrayListUnmanaged(vm.Byte) = .{},
    block_locs: std.ArrayListUnmanaged(struct { block_no: u64, iploc: u64 }) = .{},
    linking_locs: std.ArrayListUnmanaged(struct { location: u64, to_block: u64 }) = .{},

    inline fn push_bytes(self: *@This(), byte: []const vm.Byte) void {
        self.stream.append(self.alloc, byte) catch std.debug.panic("", .{});
    }

    fn translate_instruction(self: *@This(), instr: ir.Instruction) void {
        switch (instr) {
            .Integer => {
                var bytes = std.mem.toBytes(instr.data.Integer);
                var arr = [9]u8{};
                arr[0] = vm.Byte.PushInt;
                for (0..7) |idx|
                    arr[idx + 1] = bytes[idx];
                self.push_bytes(arr);
            },

            .Double => {
                var bytes = std.mem.toBytes(instr.data.Double);
                var arr = [9]u8{};
                arr[0] = vm.Byte.PushInt;
                for (0..7) |idx|
                    arr[idx + 1] = bytes[idx];
                self.push_bytes(arr);
            },

            .Add => {
                if (instr.type == .Integer)
                    self.push_bytes(&.{vm.Byte.AddInt})
                else
                    self.push_bytes(&.{vm.Byte.AddDub});
            },

            .Sub => {
                if (instr.type == .Integer)
                    self.push_bytes(&.{vm.Byte.SubInt})
                else
                    self.push_bytes(&.{vm.Byte.SubDub});
            },

            .Mul => {
                if (instr.type == .Integer)
                    self.push_bytes(&.{vm.Byte.MulInt})
                else
                    self.push_bytes(&.{vm.Byte.MulDub});
            },

            .Div => {
                self.push_bytes(&.{vm.Byte.DivDub});
            },

            .Negation => {
                if (instr.type == .Integer)
                    self.push_bytes(&.{vm.Byte.NegateInt})
                else
                    self.push_bytes(&.{vm.Byte.NegateDub});
            },
        }
    }

    fn translate_block(self: *@This(), block: ir.Block) void {
        for (block.instructions.items) |instr| {
            self.translate_instruction(instr);
        }
    }

    fn translate(self: *@This(), func: ir.Function) vm.Function {
        for (func.blocks.items) |bidx|
            self.translate_block(self.program.blocks.items[bidx]);

        return vm.Function{
            .name = func.name,
            .hash = std.hash.CityHash64.hash(func.name),
            .bytes = self.stream,
            .consts = &.{},
        };
    }
};

const Translator = struct {
    alloc: std.mem.Allocator,
    program: ir.Program,
    stream: std.ArrayListUnmanaged(vm.Byte) = .{},

    functions: std.ArrayListUnmanaged(vm.Function) = .{},

    fn translate(self: *@This()) vm.Executable {
        for (self.program.functions.items) |func|
            self.functions.append(
                self.alloc,
                (FunctionTranslator{ .alloc = self.alloc, .program = self.program }).translate(func),
            ) catch std.debug.panic("", .{});

        return vm.Executable{
            .functions = self.functions,
            .predefined_globals = .{},
        };
    }
};

pub fn translate(alloc: std.mem.Allocator, program: ir.Program) vm.Executable {
    return (Translator{
        .alloc = alloc,
        .program = program,
    }).translate();
}
