const std = @import("std");
const obj = @import("./obj.zig");
const mem = std.mem;
const heap = std.heap;
const debug = std.debug;

const Program = @import("./program.zig").Program;

const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});

const glad = @import("glad.zig");

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
        else => {},
    }
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

    const teddy = try obj.parseObj(
        heap.page_allocator,
        obj.teddy_data,
    );

    // const vertices = [_]f32{ -0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 0.5 };
    // var vs = [_]f32{
    //     -0.5, -0.5, 0.0, 0.5, -0.5, 0.0, 0.5, 0.5, 0.0, -0.5, 0.5, 0.0,
    // };
    // var vs = [_]obj.Vertex(4, f32){
    //     .{ .data = [4]f32{ -0.5, -0.5, 0.0, 1.0 } },
    //     .{ .data = [4]f32{ 0.5, -0.5, 0.0, 1.0 } },
    //     .{ .data = [4]f32{ 0.5, 0.5, 0.0, 1.0 } },
    //     .{ .data = [4]f32{ -0.5, 0.5, 0.0, 1.0 } },
    // };
    // var is = [_]u32{ 0, 1, 2, 2, 3, 0 };
    var vs = [_]obj.Vertex(4, f32){
        .{ .data = [4]f32{ -1.000000, -0.993521, 0.113647, 1.0 } },
        .{ .data = [4]f32{ 1.000000, -0.993642, 0.112588, 1.0 } },
        .{ .data = [4]f32{ -1.000000, 0.993642, -0.112588, 1.0 } },
        .{ .data = [4]f32{ 1.000000, 0.993521, -0.113647, 1.0 } },
    };
    // var vs = [_]f32{
    //     -1.000000, -0.993521, 0.113647,  1.0,
    //     1.000000,  -0.993642, 0.112588,  1.0,
    //     -1.000000, 0.993642,  -0.112588, 1.0,
    //     1.000000,  0.993521,  -0.113647, 1.0,
    // };
    var is = [_]u32{ 1, 2, 4, 3 };
    const o = obj.Obj{
        .name = "hello",
        .vertices = vs[0..],
        .indices = is[0..],
        .normals = &[_]obj.Vertex(3, f32){},
    };

    var vertex_buffer: glad.GLuint = undefined;
    glad.glGenBuffers(1, &vertex_buffer);
    panicOnError("vertex genbuffer");
    glad.glBindBuffer(glad.GL_ARRAY_BUFFER, vertex_buffer);
    panicOnError("vertex bindbuffer");
    glad.glBufferData(
        glad.GL_ARRAY_BUFFER,
        teddy.vertexBufferSize(),
        teddy.vertices.ptr,
        glad.GL_STATIC_DRAW,
    );
    panicOnError("vertex bufferdata");
    defer glad.glDeleteBuffers(1, &vertex_buffer);

    var vertex_array_object: glad.GLuint = undefined;
    glad.glGenVertexArrays(1, &vertex_array_object);
    panicOnError("gen vertex array object");
    glad.glBindVertexArray(vertex_array_object);
    panicOnError("bind vertex array object");
    defer glad.glDeleteVertexArrays(1, &vertex_array_object);

    glad.glEnableVertexAttribArray(0);
    panicOnError("vertex enable attrib array");
    glad.glVertexAttribPointer(
        0,
        teddy.vertexSize(),
        glad.GL_FLOAT,
        glad.GL_FALSE,
        teddy.vertexStride(),
        null,
    );
    panicOnError("vertex attribpointer");

    // const indices = [_]u32{ 0, 1, 2, 2, 3, 0 };
    var index_buffer_object: glad.GLuint = undefined;
    glad.glGenBuffers(1, &index_buffer_object);
    panicOnError("index genbuffer");
    glad.glBindBuffer(glad.GL_ELEMENT_ARRAY_BUFFER, index_buffer_object);
    panicOnError("index bindbuffer");
    glad.glBufferData(
        glad.GL_ELEMENT_ARRAY_BUFFER,
        teddy.indexBufferSize(),
        teddy.indices.ptr,
        glad.GL_STATIC_DRAW,
    );
    panicOnError("index bufferdata");
    defer glad.glDeleteBuffers(1, &index_buffer_object);

    var program = try Program.create(vertex_shader_source, fragment_shader_source);
    program.use();
    panicOnError("use shaders");
    defer program.delete();

    var gl_error: c_uint = glad.glGetError();
    std.debug.warn("gl_error before loop: {}\n", .{gl_error});

    while (glfw.glfwWindowShouldClose(window) == glad.GL_FALSE) {
        glad.glClear(glad.GL_COLOR_BUFFER_BIT);
        panicOnError("clear");

        glad.glDrawElements(
            glad.GL_TRIANGLES,
            @intCast(c_int, teddy.indices.len),
            glad.GL_UNSIGNED_INT,
            null,
        );
        panicOnError("glDrawElements");

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
    \\    gl_Position = position * vec4(1, 1, 1, 15);
    \\}
;

const fragment_shader_source =
    \\#version 330 core
    \\
    \\layout(location = 0) out vec4 color;
    \\
    \\void main(void) {
    \\    color = vec4(0.5, 0.5, 0.5, 1.0);
    \\}
;
