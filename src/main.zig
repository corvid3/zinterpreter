const std = @import("std");

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
}