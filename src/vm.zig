const std = @import("std");

const Byte = enum(u8) {
    // perform no operation
    NoOp = 0x00,

    PushInt = 0x10,
    PushDub = 0x11,

    AddInt = 0x20,
    SubInt = 0x21,
    MulInt = 0x22,

    AddDub = 0x25,
    SubDub = 0x26,
    MulDub = 0x27,
    DivDub = 0x28,

    // immediately halt the execution engine
    Halt = 0xFF,
};

const Value = union(enum(u8)) {
    Dub: f64,
    Int: i64,

    // all strings are clone-only
    String: []u8,

    FuncPtr: *const Function,
};

const Function = struct {
    hash: u64,
    name: []const u8,
    bytes: []const Byte,
    consts: []const Value,
};

const Executable = struct {
    functions: []const Function,
    predefined_globals: []const struct { .val = Value, .name = []const u8 },
};

const ExecutionFrame = struct {
    funcdat: *const Function,

    ip: u64,
    local_vars: [256]Value,
};

const VMError = error{
    MalformedFunction,
    MalformedGlobal,

    NoSuchFunction,
};

const VM = struct {
    const Self = @This();

    alloc: std.mem.Allocator,

    // uses the function hash as a key
    functions: std.AutoHashMapUnmanaged(u64, Function) = .{},
    global_vars: std.StringHashMapUnmanaged(Value) = .{},
    frames: std.ArrayListUnmanaged(ExecutionFrame) = .{},

    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .alloc = alloc,
        };
    }

    /// reset the engines state
    pub fn reset(self: *Self) void {
        self.functions.clearAndFree(self.alloc);
        self.global_vars.clearAndFree(self.alloc);
        self.frames.clearAndFree(self.alloc);
    }

    /// reset the engines state, then load an executable
    pub fn load_executable(self: *Self, exec: Executable) VMError!void {
        for (exec.functions) |f|
            self.functions.put(
                self.alloc,
                f.hash,
                f,
            ) catch return error.MalformedFunction;

        for (exec.predefined_globals) |g|
            self.global_vars.put(
                self.alloc,
                g.name,
                g.val,
            ) catch return error.MalformedGlobal;
    }

    pub fn run_function_str(self: *Self, name: []const u8) VMError!void {
        var func = self.functions.get(name) orelse return VMError.NoSuchFunction;
        _ = func;
    }

    inline fn current_frame(self: *Self) *ExecutionFrame {
        return self.frames.getLast();
    }
};
