const std = @import("std");
const _diagnostics = @import("diagnostics.zig");

// TODO: allow instructions to refer back to the token queue and AST, for diagnostic analysis

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
    instructions: std.ArrayListUnmanaged(Instruction) = .{},
};

pub const Instruction = struct {
    tag: Tag,
    data: Data = .{ .Null = {} },
    type: Type,

    pub const Tag = enum(u8) {
        Add,
        Sub,
        Mul,
        Div,

        Negation,

        Integer,
        Double,
        Void,

        Return,
    };

    pub const Data = union {
        Null: void,
        Integer: i64,
        Double: f64,

        Binary: struct { left: u64, right: u64 },
        Unary: u64,
    };

    // the resultant type of the SSA operation, e.g. an addition of two integers => integer
    pub const Type = union(enum(u4)) {
        /// the undecided Type is used for type propogation, where a type is unknown,
        /// e.g.
        ///    %1 = 2: Int
        ///    %2 = 3: Int
        ///    %3 = ADD(%1, %2) : Undecided
        Undecided,

        /// the type of an instruction where type-resolution/propogration has failed,
        /// allows the rest of the program to still be type-resolved, but still fail
        Invalid,

        Void,
        Integer,
        Double,

        /// uses a 60b-length unsigned integer hash ID that is associated with a custom structure type
        Structure: u64,
    };
};

/// taking in two types, corresponding to a binary operation
pub fn typeResolution(
    program: *Program,
    tag: Instruction.Tag,
    operands: []const *Instruction,
) !Instruction.Type {
    _ = program;
    return switch (tag) {
        .Add => {
            if (operands[0].type == .Integer and operands[1].type == .Integer)
                .Integer
            else if ((operands[0].type == .Double or operands[0].type == .Integer) and (operands[1].type == .Double or operands[1].type == .Integer))
                .Double
            else
                return error.InvalidTypes;
        },

        else => Instruction.Type.Null,
    };
}

/// performs type propogration on a program
pub fn typePropogation(diagnostics: _diagnostics.DiagnosticQueue, program: *Program) void {
    for (program.functions.items) |f| {
        for (f.blocks.items) |b| {
            for (b.instructions.items) |*_instr| {
                var instr: *Instruction = _instr;
                switch (instr.tag) {
                    .Add => {
                        instr.type = typeResolution(program, .Add, &.{ instr.data.Binary.left, instr.data.Binary.right }) catch x: {
                            diagnostics.push_error(_diagnostics.Diagnostic{
                                .what = "Invalid types of a binary add operation",
                                .where = "",
                            });
                            break :x .Invalid;
                        };
                    },
                    else => {},
                }
            }
        }
    }
}

fn pretty_print_instruction(program: Program, block: *const Block, str: std.ArrayListUnmanaged(u8).Writer, instridx: u64) void {
    _ = program;
    const instrtag = block.instructions.items[instridx].tag;
    const instrdata = block.instructions.items[instridx].data;
    const instrtype = block.instructions.items[instridx].type;

    std.fmt.format(str, "{d}", .{instridx}) catch std.debug.panic("", .{});

    // TODO: make this less ugly
    _ = switch (instrtag) {
        .Integer => std.fmt.format(str, "\x1b[8GINTEGER: {d}\x1b[30G{s}\n", .{
            instrdata.Integer,
            @tagName(instrtype),
        }),

        .Double => std.fmt.format(str, "\x1b[8GDOUBLE: {d}\x1b[30G{s}\n", .{
            instrdata.Integer,
            @tagName(instrtype),
        }),

        .Void => std.fmt.format(str, "\x1b[8GVOID\x1b[30G{s}\n", .{
            @tagName(instrtype),
        }),

        .Negation => std.fmt.format(str, "\x1b[8GNEGATE: {d}\x1b[30G{s}\n", .{
            instrdata.Unary,
            @tagName(instrtype),
        }),

        .Add => std.fmt.format(str, "\x1b[8GADD: {d} {d}\x1b[30G{s}\n", .{
            instrdata.Binary.left,
            instrdata.Binary.right,
            @tagName(instrtype),
        }),

        .Sub => std.fmt.format(str, "\x1b[8GSUB: {d} {d}\x1b[30G{s}\n", .{
            instrdata.Binary.left,
            instrdata.Binary.right,
            @tagName(instrtype),
        }),

        .Mul => std.fmt.format(str, "\x1b[8GMUL: {d} {d}\x1b[30G{s}\n", .{
            instrdata.Binary.left,
            instrdata.Binary.right,
            @tagName(instrtype),
        }),

        .Div => std.fmt.format(str, "\x1b[8GDIV: {d} {d}\x1b[30G{s}\n", .{
            instrdata.Binary.left,
            instrdata.Binary.right,
            @tagName(instrtype),
        }),

        .Return => std.fmt.format(str, "\x1b[8GRETURN: {d}\x1b[30G{s}\n", .{
            instrdata.Unary,
            @tagName(instrtype),
        }),
    } catch std.debug.panic("", .{});
}

fn pretty_print_block(program: Program, blockidx: u64, str: std.ArrayListUnmanaged(u8).Writer) void {
    const block = program.blocks.items[blockidx];
    std.fmt.format(str, "  BLOCK {d}:\n", .{blockidx}) catch std.debug.panic("", .{});

    for (0..block.instructions.items.len) |iidx|
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
