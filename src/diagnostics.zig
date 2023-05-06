const std = @import("std");

// we pay no technical debt to panicking on errors here no sirree

pub const Diagnostic = struct {
    /// description of the error
    what: []const u8,

    /// slice into the lexed file
    where: []const u8,
};

pub const DiagnosticQueue = struct {
    alloc: std.mem.Allocator,

    errors: std.ArrayListUnmanaged(Diagnostic) = .{},
    warnings: std.ArrayListUnmanaged(Diagnostic) = .{},

    pub fn init(alloc: std.mem.Allocator) DiagnosticQueue {
        return DiagnosticQueue{ .alloc = alloc };
    }

    pub fn deinit(self: *DiagnosticQueue) void {
        self.errors.deinit(self.alloc);
        self.warnings.deinit(self.alloc);
    }

    pub inline fn has_errors(self: *DiagnosticQueue) bool {
        return self.errors.items.len != 0;
    }

    pub inline fn push_error(self: *DiagnosticQueue, diagnostic: Diagnostic) void {
        self.errors.append(self.alloc, diagnostic) catch std.debug.panic("", .{});
    }

    pub inline fn push_warning(self: *DiagnosticQueue, diagnostic: Diagnostic) void {
        self.warnings.append(self.alloc, diagnostic) catch std.debug.panic("", .{});
    }

    /// writes all diagnostics in order to a string which is returned
    /// caller owns returned string
    pub fn display_all(self: *DiagnosticQueue) ![]u8 {
        var str = std.ArrayList(u8).init(self.alloc);

        for (self.errors.items) |e| {
            try std.fmt.format(
                str.writer(),
                "\x1b[31;49mERROR\x1b[39;49m: {s}\n",
                .{e.what},
            );
        }

        for (self.warnings.items) |w| {
            try std.fmt.format(
                str.writer(),
                "\x1b[32;49mWARNING\x1b[39;49m: {s}\n",
                .{w.what},
            );
        }

        return str.toOwnedSlice() catch std.debug.panic(
            "Memory error in DiagnosticQueue.display_all\n",
            .{},
        );
    }
};
