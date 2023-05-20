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
    Null: void,

    Dub: f64,
    Int: i64,

    // all strings are clone-only
    String: []u8,

    FuncPtr: *const Function,
};

pub const Function = struct {
    hash: u64,
    name: []const u8,
    bytes: std.ArrayListUnmanaged(u8),
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

/// traditional stack-based execution engine
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
        for (exec.functions.items) |f|
            self.functions.put(
                self.alloc,
                f.hash,
                f,
            ) catch return error.MalformedFunction;

        for (exec.predefined_globals.items) |g|
            self.global_vars.put(
                self.alloc,
                g.name,
                g.val,
            ) catch return error.MalformedGlobal;
    }

    pub fn run_function_str(self: *Self, name: []const u8) VMError!void {
        var func = self.functions.get(std.hash.CityHash64.hash(name)) orelse return VMError.NoSuchFunction;
        _ = func;
    }

    inline fn current_frame(self: *Self) *ExecutionFrame {
        return self.frames.getLast();
    }
};

/// experimental, recursive VM
pub const RVM = struct {
    const Context = struct {
        const Self = @This();

        alloc: std.mem.Allocator,

        functions: std.AutoHashMapUnmanaged(u64, Function) = .{},
        global_vars: std.StringHashMapUnmanaged(Value) = .{},

        pub fn run_function(self: *Self, name: []const u8) !Value {
            var func = self.functions.getPtr(std.hash.CityHash64.hash(name)) orelse return VMError.NoSuchFunction;
            var sf = try StackFrame.init(self, func);
            return try sf.run();
        }
    };

    const StackFrame = struct {
        const Self = @This();

        context: *Context,
        assoc_func: *const Function,
        ip: u64 = 0,
        stack: std.ArrayListUnmanaged(Value),

        fn init(context: *Context, assoc_func: *const Function) !Self {
            return Self{
                .context = context,
                .assoc_func = assoc_func,
                .stack = try std.ArrayListUnmanaged(Value).initCapacity(context.alloc, 512),
            };
        }

        fn deinit(self: *Self) void {
            self.stack.deinit(self.context.alloc);
        }

        inline fn next_u8(self: *Self) !u8 {
            var byte = self.assoc_func.bytes.items[self.ip];
            self.ip += 1;
            return byte;
        }

        inline fn next_u16(self: *Self) !u16 {
            var short = @ptrCast(*align(1) u16, &self.assoc_func.bytes.items[self.ip]).*;
            self.ip += 2;
            return short;
        }

        inline fn next_u32(self: *Self) !u32 {
            var long = @ptrCast(*align(1) u32, &self.assoc_func.bytes.items[self.ip]).*;
            self.ip += 3;
            return long;
        }

        inline fn next_u64(self: *Self) !u64 {
            var longlong = @ptrCast(*align(1) u64, &self.assoc_func.bytes.items[self.ip]).*;
            self.ip += 7;
            return longlong;
        }

        inline fn pop(self: *Self) Value {
            return self.stack.pop();
        }

        /// runs until crashing, or returns a value
        fn run(self: *Self) !Value {
            defer self.deinit();

            while (true) {
                var byte = @intToEnum(Byte, self.assoc_func.bytes.items[self.ip]);

                switch (byte) {
                    .NoOp => self.ip += 1,
                    .PushNull => try self.stack.append(self.context.alloc, .{ .Null = {} }),
                    .PushInt => try self.stack.append(self.context.alloc, .{ .Int = @bitCast(i64, try self.next_u64()) }),

                    .AddInt => try self.stack.append(self.context.alloc, .{ .Int = self.pop().Int + self.pop().Int }),

                    .Return => return self.stack.pop(),

                    else => std.debug.panic("", .{}),
                }
            }
        }
    };

    pub fn init(alloc: std.mem.Allocator, exec: Executable) !Context {
        var ctx = Context{
            .alloc = alloc,
        };

        for (exec.functions.items) |f|
            try ctx.functions.put(alloc, std.hash.CityHash64.hash(f.name), f);

        for (exec.predefined_globals.items) |g|
            try ctx.global_vars.put(alloc, g.name, g.val);

        return ctx;
    }
};
