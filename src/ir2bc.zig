const std = @import("std");
const ir = @import("ir.zig");
const vm = @import("vm.zig");

const FunctionTranslator = struct {
    alloc: std.mem.Allocator,
    program: ir.Program,

    stream: std.ArrayListUnmanaged(u8) = .{},

    /// this array contains a list of adresses into the stream, which point to
    /// the first instruction of an associated block
    block_locs: std.ArrayListUnmanaged(struct { block_no: u64, iploc: u64 }) = .{},

    /// this array contains a list of addresses, that point to the address
    /// part of the "branch" instructions, where an address must be supplied
    /// that points to an associated block, where the address of the block
    /// required can be found in "block_locs"
    linking_locs: std.ArrayListUnmanaged(struct { location: u64, to_block: u64 }) = .{},

    inline fn push_bytes(self: *@This(), byte: []const u8) void {
        self.stream.appendSlice(
            self.alloc,
            byte,
        ) catch std.debug.panic(
            "",
            .{},
        );
    }

    fn translate_instruction(self: *@This(), instr: ir.Instruction) void {
        switch (instr.tag) {
            .Integer => {
                var bytes = std.mem.toBytes(instr.data.Integer);
                var arr: [9]u8 = .{0} ** 9;
                arr[0] = @enumToInt(vm.Byte.PushInt);
                for (0..7) |idx|
                    arr[idx + 1] = bytes[idx];
                self.push_bytes(&arr);
            },

            .Double => {
                var bytes = std.mem.toBytes(instr.data.Integer);
                var arr: [9]u8 = .{0} ** 9;
                arr[0] = @enumToInt(vm.Byte.PushDub);
                for (0..7) |idx|
                    arr[idx + 1] = bytes[idx];
                self.push_bytes(&arr);
            },

            .Void => {
                self.push_bytes(&.{@enumToInt(vm.Byte.PushNull)});
            },

            .Add => {
                if (instr.type == .Integer)
                    self.push_bytes(&.{@enumToInt(vm.Byte.AddInt)})
                else
                    self.push_bytes(&.{@enumToInt(vm.Byte.AddDub)});
            },

            .Sub => {
                if (instr.type == .Integer)
                    self.push_bytes(&.{@enumToInt(vm.Byte.SubInt)})
                else
                    self.push_bytes(&.{@enumToInt(vm.Byte.SubDub)});
            },

            .Mul => {
                if (instr.type == .Integer)
                    self.push_bytes(&.{@enumToInt(vm.Byte.MulInt)})
                else
                    self.push_bytes(&.{@enumToInt(vm.Byte.MulDub)});
            },

            .Div => {
                self.push_bytes(&.{@enumToInt(vm.Byte.DivDub)});
            },

            .Negation => {
                if (instr.type == .Integer)
                    self.push_bytes(&.{@enumToInt(vm.Byte.NegateInt)})
                else
                    self.push_bytes(&.{@enumToInt(vm.Byte.NegateDub)});
            },

            .Return => {
                // pops the top of the stack, and returns the value
                self.push_bytes(&.{@enumToInt(vm.Byte.Return)});
            },
        }
    }

    fn translate_block(self: *@This(), block: ir.Block) void {
        for (block.items) |instr| {
            self.translate_instruction(instr);
        }
    }

    fn translate(self: *@This(), func: ir.Function) vm.Function {
        for (func.blocks.items) |block|
            self.translate_block(block);

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
