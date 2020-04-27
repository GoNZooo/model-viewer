const std = @import("std");
const obj = @import("./obj.zig");
const mem = std.mem;
const heap = std.heap;
const debug = std.debug;
const math = std.math;

const Program = @import("./program.zig").Program;

const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});

const glad = @import("glad.zig");

var red_color: f32 = 1.0;
var green_color: f32 = 0.0;
var blue_color: f32 = 0.0;

fn errorCallback(err: c_int, description: [*c]const u8) callconv(.C) void {
    var message: [*:0]const u8 = description;
    std.debug.panic("GLFW error ({}): {s}\n", .{ err, message });
}

fn handleKey(
    window: ?*glfw.GLFWwindow,
    key: c_int,
    scancode: c_int,
    action: c_int,
    mods: c_int,
) callconv(.C) void {
    if (action != glfw.GLFW_PRESS) return;

    switch (key) {
        glfw.GLFW_KEY_ESCAPE, glfw.GLFW_KEY_Q => {
            glfw.glfwSetWindowShouldClose(window, glfw.GL_TRUE);
        },
        glfw.GLFW_KEY_R => {
            if (mods & 0b1 == 1) {
                red_color = clampedDecrease(red_color, 0.1, 0.0);
            } else {
                red_color = clampedIncrease(red_color, 0.1, 1.0);
            }
            debug.warn(
                "color: {}/{}/{}\n",
                .{
                    normalizeFloatToInt(u8, 255, red_color),
                    normalizeFloatToInt(u8, 255, green_color),
                    normalizeFloatToInt(u8, 255, blue_color),
                },
            );
        },
        glfw.GLFW_KEY_G => {
            if (mods & 0b1 == 1) {
                green_color = clampedDecrease(green_color, 0.1, 0.0);
            } else {
                green_color = clampedIncrease(green_color, 0.1, 1.0);
            }
            debug.warn(
                "color: {}/{}/{}\n",
                .{
                    normalizeFloatToInt(u8, 255, red_color),
                    normalizeFloatToInt(u8, 255, green_color),
                    normalizeFloatToInt(u8, 255, blue_color),
                },
            );
        },
        glfw.GLFW_KEY_B => {
            if (mods & 0b1 == 1) {
                blue_color = clampedDecrease(blue_color, 0.1, 0.0);
            } else {
                blue_color = clampedIncrease(blue_color, 0.1, 1.0);
            }
            debug.warn(
                "color: {}/{}/{}\n",
                .{
                    normalizeFloatToInt(u8, 255, red_color),
                    normalizeFloatToInt(u8, 255, green_color),
                    normalizeFloatToInt(u8, 255, blue_color),
                },
            );
        },
        else => {},
    }
}

fn normalizeFloatToInt(comptime T: type, bounds: T, value: f32) T {
    return @floatToInt(T, value * @intToFloat(f32, bounds));
}

fn clampedDecrease(f: f32, decrease: f32, bottom: f32) f32 {
    return math.max(f - decrease, bottom);
}

fn clampedIncrease(f: f32, increase: f32, top: f32) f32 {
    return math.min(f + increase, top);
}

pub fn main() anyerror!void {
    _ = glfw.glfwSetErrorCallback(errorCallback);
    if (glfw.glfwInit() == glad.GL_FALSE) @panic("glfwInit() failed\n");
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 5);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_DEBUG_CONTEXT, glad.GL_TRUE);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);
    // glfw.glfwWindowHint(glfw.GLFW_OPENGL_FORWARD_COMPAT, glad.GL_TRUE);
    // glfw.glfwWindowHint(glfw.GLFW_DEPTH_BITS, 0);
    // glfw.glfwWindowHint(glfw.GLFW_STENCIL_BITS, 8);
    // glfw.glfwWindowHint(glfw.GLFW_RESIZABLE, glad.GL_FALSE);

    var window = glfw.glfwCreateWindow(1280, 1280, "MView", null, null) orelse {
        std.debug.panic("unable to create window\n", .{});
    };
    defer glfw.glfwDestroyWindow(window);

    glfw.glfwMakeContextCurrent(window);
    const loaded = glad.gladLoadGLLoader(glfw.glfwGetProcAddress);
    std.debug.warn("loaded: {}\n", .{loaded});
    glfw.glfwSwapInterval(1);

    const gl_version: [*:0]const u8 = glfw.glGetString(glfw.GL_VERSION);
    const gl_vendor: [*:0]const u8 = glfw.glGetString(glfw.GL_VENDOR);
    std.debug.warn("GL version: {s}\n", .{gl_version});
    std.debug.warn("GL vendor: {s}\n", .{gl_vendor});

    _ = glfw.glfwSetKeyCallback(window, handleKey);
    var width: c_int = undefined;
    var height: c_int = undefined;
    glfw.glfwGetFramebufferSize(window, &width, &height);
    std.debug.warn("viewport: {}x{}\n", .{ width, height });

    const rough_sphere_on_cube = try obj.parseObj(
        heap.page_allocator,
        obj.rough_sphere_on_cube_data,
    );

    var teddy = try obj.parseObj(
        heap.page_allocator,
        obj.teddy_data,
    );

    var program = try Program.create(vertex_shader_source, fragment_shader_source);
    program.use();
    panicOnError("use shaders");
    defer program.delete();

    const uniform_location = glad.glGetUniformLocation(program.id, "u_Color");

    var gl_error: c_uint = glad.glGetError();
    std.debug.warn("gl_error before loop: {}\n", .{gl_error});

    while (glfw.glfwWindowShouldClose(window) == glad.GL_FALSE) {
        glad.glClear(glad.GL_COLOR_BUFFER_BIT);
        panicOnError("clear");
        glad.glUniform4f(uniform_location, red_color, green_color, blue_color, 1.0);

        teddy.render();

        glfw.glfwSwapBuffers(window);

        glfw.glfwPollEvents();
    }
}

fn panicOnError(comptime label: []const u8) void {
    printGlError(
        label,
        ErrorPrintOptions{ .warn_on_no_error = false, .panic_on_error = true },
    );
}

const ErrorPrintOptions = struct {
    warn_on_no_error: bool,
    panic_on_error: bool,
};

fn printGlError(comptime label: []const u8, comptime options: ErrorPrintOptions) void {
    var gl_error = glad.glGetError();
    const is_end = mem.eql(u8, label, "end");
    if (!is_end) {
        if (gl_error != glad.GL_NO_ERROR) {
            std.debug.warn("{} is end?: {}", .{ label, is_end });
            std.debug.warn("\n\t", .{});
        } else if (options.warn_on_no_error) {
            std.debug.warn("{}: no error\n", .{label});
        }
        switch (gl_error) {
            glad.GL_INVALID_ENUM => std.debug.warn("GL error: invalid enum\n", .{}),
            glad.GL_INVALID_VALUE => std.debug.warn("GL error: invalid value\n", .{}),
            glad.GL_INVALID_OPERATION => std.debug.warn("GL error: invalid operation\n", .{}),
            glad.GL_INVALID_FRAMEBUFFER_OPERATION => std.debug.warn(
                "GL error: invalid framebuffer op\n",
                .{},
            ),
            glad.GL_OUT_OF_MEMORY => std.debug.warn("GL error: out of memory\n", .{}),
            glad.GL_STACK_UNDERFLOW => std.debug.warn("GL error: stack underflow\n", .{}),
            glad.GL_STACK_OVERFLOW => std.debug.warn("GL error: stack overflow\n", .{}),
            glad.GL_NO_ERROR => {},
            else => unreachable,
        }
        if (gl_error != glad.GL_NO_ERROR and options.panic_on_error) std.process.exit(1);
    }
}

// \\uniform mat4 MVP;
// \\
const vertex_shader_source =
    \\#version 330 core
    \\
    \\layout(location = 0) in vec4 position;
    \\
    \\void main(void) {
    \\    gl_Position = position * vec4(1, 1, 1, 23);
    \\}
;

const fragment_shader_source =
    \\#version 330 core
    \\
    \\layout(location = 0) out vec4 color;
    \\uniform vec4 u_Color;
    \\
    \\void main(void) {
    \\    color = u_Color;
    \\}
;
