const std = @import("std");
const _diagnostics = @import("diagnostics.zig");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");

// allow for a max source-file size of 1M
const MAX_FILESIZE = 1024 * 1024;

const Arguments = struct {
    alloc: std.mem.Allocator,
    filename: ?[]const u8 = null,

    pub fn get_args(alloc: std.mem.Allocator) !Arguments {
        var args = try std.process.argsWithAllocator(alloc);
        defer args.deinit();

        // skip argv[0] (the process name)
        _ = args.next();

        var self = Arguments{ .alloc = alloc };

        while (args.next()) |arg| {
            if (!std.mem.startsWith(u8, arg, "-"))
                self.filename = try alloc.dupe(u8, arg)
            else
                return error.UnknownOption;
        }

        return self;
    }

    pub fn deinit(self: *Arguments) void {
        if (self.filename) |filename|
            self.alloc.free(filename);
    }
};

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    var diagnostics = _diagnostics.DiagnosticQueue.init(alloc);
    defer diagnostics.deinit();

    var args = Arguments.get_args(alloc) catch |e| {
        switch (e) {
            error.UnknownOption => {
                std.debug.print("Unknown option in arguments supplied.\n", .{});
                return;
            },

            else => return e,
        }
    };

    defer args.deinit();

    if (args.filename == null) {
        std.debug.print("Filename not supplied.\n", .{});
        return;
    }

    std.debug.print("filename supplied: {s}\n", .{args.filename.?});

    var file = std.fs.cwd().openFile(args.filename.?, .{}) catch {
        std.debug.print(
            "File {s} does not exist, or a related error occured.\n",
            .{args.filename.?},
        );

        return;
    };

    defer file.close();

    var filedata = try file.readToEndAlloc(alloc, MAX_FILESIZE);
    defer alloc.free(filedata);

    std.debug.print("filedata: \n{s}\n", .{filedata});

    var toks = try lexer.lex(alloc, &diagnostics, filedata);

    var tokt = toks.items(.tag);
    var toksl = toks.items(.slice);
    for (0..toks.len) |l| {
        std.debug.print("{?} {?}\n", .{ tokt[l], toksl[l].len });
    }

    // if there are errors in the lexing step, print, and halt
    if (diagnostics.has_errors()) {
        var d = try diagnostics.display_all();
        try std.io.getStdOut().writeAll(d);
        alloc.free(d);
    }

    var nodes = parser.parse(alloc, &diagnostics, toks) catch {
        var d = try diagnostics.display_all();
        try std.io.getStdOut().writeAll(d);
        alloc.free(d);
        return;
    };

    _ = nodes;
}
