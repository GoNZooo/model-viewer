const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const testing = std.testing;

const c = @cImport({
    @cInclude("stb_image.h");
});

pub const Image = struct {
    const Self = @This();

    width: u32,
    height: u32,
    channels: u32,
    data: []const u8,

    pub fn fromPath(path: []const u8) !Image {
        var width: c_int = undefined;
        var height: c_int = undefined;
        var channels: c_int = undefined;
        const data = c.stbi_load(path.ptr, &width, &height, &channels, 0);

        if (data == null) return error.UnableToLoadImage;

        return Self{
            .width = @intCast(u32, width),
            .height = @intCast(u32, height),
            .channels = @intCast(u32, channels),
            .data = mem.span(data),
        };
    }
};

test "load 'hello.png'" {
    const hello = try Image.fromPath("./res/textures/hello.png");
    testing.expectEqual(hello.data.len, 437874);
    testing.expectEqual(hello.width, 497);
    testing.expectEqual(hello.height, 454);
    testing.expectEqual(hello.channels, 4);
}
