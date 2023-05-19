const std = @import("std");

pub const Program = struct {
    functions: std.ArrayListUnmanaged(Function) = .{},
    blocks: std.ArrayListUnmanaged(Block) = .{},
};

pub const Function = struct {
    name: []const u8,

    // contains a list of indexes into the block-list
    // the first block is the "begin" block
    blocks: std.ArrayListUnmanaged(u64),
};

pub const Block = struct {
    instructions: std.MultiArrayList(Instruction) = .{},
};

pub const Instruction = struct {
    tag: Tag,
    data: Data,
    type: Type,

    pub const Tag = enum(u8) {
        Add,
        Sub,
        Mul,
        Div,

        Negation,

        Integer,
        Double,
    };

    pub const Data = union {
        null: void,
        Integer: i64,
        Double: f64,

        Binary: struct { left: u64, right: u64 },
        Unary: u64,
    };

    // the resultant type of the SSA operation, e.g. an addition of two integers => integer
    pub const Type = enum(u8) {
        Integer,
        Double,
    };
};

fn pretty_print_instruction(program: Program, block: *const Block, str: std.ArrayListUnmanaged(u8).Writer, instridx: u64) void {
    _ = program;
    const instrtag = block.instructions.items(.tag)[instridx];
    const instrdata = block.instructions.items(.data)[instridx];

    std.fmt.format(str, "{d}", .{instridx}) catch std.debug.panic("", .{});

    _ = switch (instrtag) {
        .Integer => std.fmt.format(str, "    INTEGER: {d}\n", .{instrdata.Integer}),
        .Double => std.fmt.format(str, "    DOUBLE: {d}\n", .{instrdata.Integer}),

        .Negation => std.fmt.format(str, "    NEGATE: {d}\n", .{instrdata.Unary}),

        .Add => std.fmt.format(str, "    ADD: {d} {d}\n", .{ instrdata.Binary.left, instrdata.Binary.right }),
        .Sub => std.fmt.format(str, "    SUB: {d} {d}\n", .{ instrdata.Binary.left, instrdata.Binary.right }),
        .Mul => std.fmt.format(str, "    MUL: {d} {d}\n", .{ instrdata.Binary.left, instrdata.Binary.right }),
        .Div => std.fmt.format(str, "    DIV: {d} {d}\n", .{ instrdata.Binary.left, instrdata.Binary.right }),
    } catch std.debug.panic("", .{});
}

fn pretty_print_block(program: Program, blockidx: u64, str: std.ArrayListUnmanaged(u8).Writer) void {
    const block = program.blocks.items[blockidx];
    std.fmt.format(str, "  BLOCK {d}:\n", .{blockidx}) catch std.debug.panic("", .{});

    for (0..block.instructions.len) |iidx|
        pretty_print_instruction(program, &block, str, iidx);
}

fn pretty_print_function(program: Program, function: Function, str: std.ArrayListUnmanaged(u8).Writer) void {
    std.fmt.format(str, "FUNCTION: {s}\n", .{function.name}) catch std.debug.panic("", .{});
    for (function.blocks.items) |block|
        pretty_print_block(program, block, str);
}

pub fn pretty_print(alloc: std.mem.Allocator, program: Program) std.ArrayListUnmanaged(u8) {
    var str = std.ArrayListUnmanaged(u8){};
    var strw = str.writer(alloc);

    for (program.functions.items) |func|
        pretty_print_function(program, func, strw);

    return str;
}
