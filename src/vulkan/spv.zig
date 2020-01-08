const std = @import("std");
const fs = std.fs;
const mem = std.mem;

pub fn readFile(allocator: *mem.Allocator, filepath: []const u8) ![]const u8 {
    const cwd = fs.cwd();
    const file_data = try cwd.readFileAlloc(allocator, filepath, max_file_size);

    return file_data;
}

const max_file_size = 1024 * 1024;
