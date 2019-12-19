const std = @import("std");
const mem = std.mem;

pub const rough_sphere_on_cube_data = @embedFile("../res/obj/rough-sphere-on-cube.obj");

pub const rough_sphere_on_cube = parseObj(rough_sphere_on_cube_data);

pub fn Vertex(comptime size: comptime_int, comptime T: type) type {
    return struct {
        data: [size]T,
    };
}

pub const Index3 = struct {
    data: [3][3]usize,
};

pub const Obj = struct {
    vertices: []Vertex(3, f32),
    indices: []Index3,
    normals: []Vertex(3, f32),
};

pub fn parseObj(allocator: *mem.Allocator, data: []const u8) Obj {
    return Obj{ .vertices = &[_]Vertex(3, f32){}, .indices = &[_]Index3{} };
}
