const std = @import("std");
const obj = @import("./obj.zig");

pub fn main() anyerror!void {
    // std.debug.warn("rough_sphere_on_cube_data: {}\n", obj.rough_sphere_on_cube_data);
    std.debug.warn("rough_sphere_on_cube: {}\n", obj.rough_sphere_on_cube);
}
