const std = @import("std");

fn RefCount(comptime T: type) type {
    return struct {
        const Data = @This();
        const Handle = struct {
            _data: *Data,

            pub fn deinit(self: Handle) @This() {
                self.data.uncount();
            }

            /// returns a pointer to the data contained
            /// can also be used for getting "weak references"
            pub fn data(self: Handle) *T {
                return &self._data.data;
            }

            pub fn get(self: *@This()) Handle {
                self.count += 1;
                return Handle{ .data = self };
            }

            pub fn release(self: *@This(), alloc: std.mem.Allocator) void {
                if (self.count == 0 or self.count - 1 == 0) {
                    alloc.free(self);
                } else self.count -= 1;
            }
        };

        data: T,
        count: u64,

        pub fn init(alloc: std.mem.Allocator, data: T) !Handle {
            if (@TypeOf(data) == RefCount) {}
            return alloc.create(@This()){
                .data = data,
            };
        }
    };
}

fn testing() void {
    var testingalloc = std.testing.allocator;
    var refcount: RefCount(u8).Handle = RefCount(u8).init(testingalloc).get();
    defer refcount.release();
}

pub const Byte = enum(u8) {
    // perform no operation
    NoOp = 0x00,
    PushNull = 0x01,

    PushInt = 0x10,
    PushDub = 0x11,

    AddInt = 0x20,
    SubInt = 0x21,
    MulInt = 0x22,

    AddDub = 0x25,
    SubDub = 0x26,
    MulDub = 0x27,
    DivDub = 0x28,

    NegateInt = 0x2a,
    NegateDub = 0x2b,

    Return = 0xA5,

    // immediately halt the execution engine
    Halt = 0xFF,
};

pub const Value = union(enum(u8)) {
    Dub: f64,
    Int: i64,

    // all strings are clone-only
    String: []u8,

    FuncPtr: *const Function,
};

pub const Function = struct {
    hash: u64,
    name: []const u8,
    bytes: std.ArrayListUnmanaged(Byte),
    consts: []const Value,
};

pub const Executable = struct {
    functions: std.ArrayListUnmanaged(Function),
    predefined_globals: std.ArrayListUnmanaged(struct { val: Value, name: []const u8 }),
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

pub const VM = struct {
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
