const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const testing = std.testing;
const heap = std.heap;

const c = @cImport({
    @cInclude("stb_image.h");
});

pub const Image = struct {
    const Self = @This();

    width: u32,
    height: u32,
    channels: u32,
    data: []const u8,

    pub fn fromPath(allocator: *mem.Allocator, path: []const u8) !Image {
        var width: c_int = undefined;
        var height: c_int = undefined;
        var channels: c_int = undefined;
        const raw_data = c.stbi_load(path.ptr, &width, &height, &channels, 0);
        if (raw_data == null) return error.UnableToLoadImage;
        defer c.stbi_image_free(raw_data);

        const needed_bytes = @intCast(usize, width * height * channels);
        var data = try allocator.alloc(u8, needed_bytes);
        for (data) |_, i| {
            data[i] = raw_data[i];
        }

        return Self{
            .width = @intCast(u32, width),
            .height = @intCast(u32, height),
            .channels = @intCast(u32, channels),
            .data = data,
        };
    }
};

test "load 'hello.png'" {
    const hello = try Image.fromPath(heap.page_allocator, "./res/textures/hello.png");
    testing.expectEqual(hello.width, 497);
    testing.expectEqual(hello.height, 454);
    testing.expectEqual(hello.channels, 4);
    testing.expectEqual(hello.data.len, 902_552);
}
