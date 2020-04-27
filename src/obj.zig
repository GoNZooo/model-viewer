const std = @import("std");
const mem = std.mem;
const heap = std.heap;
const debug = std.debug;
const fmt = std.fmt;
const testing = std.testing;

const ArrayList = std.ArrayList;

pub const rough_sphere_on_cube_data = @embedFile("../res/obj/rough-sphere-on-cube.obj");
pub const teddy_data = @embedFile("../res/obj/teddy.obj");

pub fn Vertex(comptime size: comptime_int, comptime T: type) type {
    return struct {
        const Self = @This();

        data: [size]T,

        fn size() c_int {
            return size * @sizeOf(T);
        }
    };
}

pub const Obj = struct {
    const Self = @This();

    name: []const u8,
    vertices: []Vertex(4, f32),
    indices: []u32,
    normals: []Vertex(3, f32),

    fn vertexBufferSize(self: Self) c_longlong {
        return Vertex(4, f32).size() * @intCast(c_longlong, self.vertices.len);
    }

    fn vertexSize(self: Self) c_int {
        return 4;
    }

    fn vertexStride(self: Self) c_int {
        return Vertex(4, f32).size();
    }

    fn indexBufferSize(self: Self) c_longlong {
        return @sizeOf(u32) * @intCast(c_longlong, self.indices.len);
    }
};

pub fn parseObj(allocator: *mem.Allocator, data: []const u8) !Obj {
    var it = mem.split(data, "\n");
    var name: []const u8 = undefined;
    var indices_list = ArrayList(u32).init(allocator);
    var vertices_list = ArrayList(Vertex(4, f32)).init(allocator);
    var normals_list = ArrayList(Vertex(3, f32)).init(allocator);
    while (it.next()) |line| {
        if (!mem.eql(u8, line, "") and line[0] != '#') {
            var command_it = mem.split(line, " ");
            const command_identifier = command_it.next().?;
            if (mem.eql(u8, command_identifier, "o")) {
                name = command_it.next().?;
            } else if (mem.eql(u8, command_identifier, "v")) {
                const x = try fmt.parseFloat(f32, command_it.next().?);
                const y = try fmt.parseFloat(f32, command_it.next().?);
                const z = try fmt.parseFloat(f32, command_it.next().?);
                const w = try fmt.parseFloat(f32, command_it.next() orelse "1.0");
                const vertex = Vertex(4, f32){ .data = [_]f32{ x, y, z, w } };
                try vertices_list.append(vertex);
            } else if (mem.eql(u8, command_identifier, "f")) {
                while (command_it.next()) |face_section| {
                    var section_it = mem.split(face_section, "/");
                    const parsed_index = try fmt.parseInt(
                        u32,
                        section_it.next().?,
                        10,
                    );
                    try indices_list.append(parsed_index - 1);
                }
            } else if (mem.eql(u8, command_identifier, "vn")) {
                const x = try fmt.parseFloat(f32, command_it.next().?);
                const y = try fmt.parseFloat(f32, command_it.next().?);
                const z = try fmt.parseFloat(f32, command_it.next().?);
                const vertex = Vertex(3, f32){ .data = [3]f32{ x, y, z } };
                try normals_list.append(vertex);
            }
        }
    }

    return Obj{
        .name = name,
        .vertices = vertices_list.items,
        .indices = indices_list.items,
        .normals = normals_list.items,
    };
}

test "parsing rough sphere on cube" {
    const rough_sphere_on_cube = try parseObj(
        heap.page_allocator,
        rough_sphere_on_cube_data,
    );
    for (rough_sphere_on_cube.vertices) |v| {
        debug.warn("v.data={} ", .{v.data});
        for (v.data) |vv| {
            debug.warn("{} ", .{vv});
        }
        debug.warn("\n", .{});
    }
    debug.warn("rough_sphere_on_cube={}\n", .{rough_sphere_on_cube});
    testing.expect(
        &rough_sphere_on_cube.vertices[0].data != &rough_sphere_on_cube.vertices[1].data,
    );
}

test "parsing crooked plane" {
    const crooked_plane = try parseObj(
        heap.page_allocator,
        crooked_plane_data,
    );
    for (crooked_plane.vertices) |v| {
        debug.warn("v.data={} ", .{v.data});
        for (v.data) |vv| {
            debug.warn("{} ", .{vv});
        }
        debug.warn("\n", .{});
    }

    for (crooked_plane.indices) |i| {
        debug.warn("i={}\n", .{i});
    }
    debug.warn("crooked_plane={}\n", .{crooked_plane});
    testing.expect(
        &crooked_plane.vertices[0].data != &crooked_plane.vertices[1].data,
    );
}
