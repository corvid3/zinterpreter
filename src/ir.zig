const std = @import("std");
const _diagnostics = @import("diagnostics.zig");

// TODO: allow instructions to refer back to the token queue and AST, for diagnostic analysis

pub const Program = struct {
    functions: std.ArrayListUnmanaged(Function) = .{},
};

pub const Function = struct {
    name: []const u8,

    // contains a list of indexes into the block-list
    // the first block is the "begin" block
    blocks: std.ArrayListUnmanaged(Block),
};

pub const Block = std.ArrayListUnmanaged(Instruction);

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

/// helper struct, not visible to the outside world
/// takes in a reference to a program, and mutates it
const TypePropogator = struct {
    const Self = @This();

    diagnostics: *_diagnostics.DiagnosticQueue,
    program: *Program,

    /// this is a mess of a method, but it works?
    /// dont touch, it's in 5 dimensions and is fragile
    fn propogate(self: *Self) void {
        for (self.program.functions.items) |f| {
            for (f.blocks.items) |b| {
                for (b.items) |*_instr| {
                    var instr: *Instruction = _instr;
                    switch (instr.tag) {
                        .Add, .Sub, .Mul => {
                            const lt = b.items[instr.data.Binary.left].type;
                            const rt = b.items[instr.data.Binary.right].type;

                            const ltt = std.meta.activeTag(lt);
                            const rtt = std.meta.activeTag(rt);

                            if ((lt != .Double and lt != .Integer) or (rt != .Double and rt != .Integer)) {
                                self.diagnostics.push_error(_diagnostics.Diagnostic{
                                    .what = "Invalid type in binary operation",
                                    .where = "",
                                });

                                instr.type = .Invalid;
                                break;
                            }

                            instr.type = if (ltt == rtt) lt else .Double;
                        },
                        else => {},
                    }
                }
            }
        }
    }
};

/// mutates program
pub fn typePropogate(program: *Program, diagnostics: *_diagnostics.DiagnosticQueue) void {
    var tp = TypePropogator{
        .diagnostics = diagnostics,
        .program = program,
    };

    tp.propogate();
}

fn pretty_print_instruction(
    function: Function,
    block: *const std.ArrayListUnmanaged(Instruction),
    str: std.ArrayListUnmanaged(u8).Writer,
    instridx: u64,
) void {
    _ = function;
    const instrtag = block.items[instridx].tag;
    const instrdata = block.items[instridx].data;
    const instrtype = block.items[instridx].type;

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

fn pretty_print_block(function: Function, blockidx: u64, str: std.ArrayListUnmanaged(u8).Writer) void {
    const block = function.blocks.items[blockidx];
    std.fmt.format(str, "  BLOCK {d}:\n", .{blockidx}) catch std.debug.panic("", .{});

    for (0..block.items.len) |iidx|
        pretty_print_instruction(function, &block, str, iidx);
}

fn pretty_print_function(program: Program, function: Function, str: std.ArrayListUnmanaged(u8).Writer) void {
    _ = program;
    std.fmt.format(str, "FUNCTION: {s}\n", .{function.name}) catch std.debug.panic("", .{});
    for (0..function.blocks.items.len) |block|
        pretty_print_block(function, block, str);
}

pub fn pretty_print(alloc: std.mem.Allocator, program: Program) std.ArrayListUnmanaged(u8) {
    var str = std.ArrayListUnmanaged(u8){};
    var strw = str.writer(alloc);

    for (program.functions.items) |func|
        pretty_print_function(program, func, strw);

    return str;
}
