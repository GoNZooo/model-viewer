const std = @import("std");
const obj = @import("./obj.zig");
const mem = std.mem;

const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});

const glad = @import("./glad.zig");

extern fn errorCallback(err: c_int, description: [*c]const u8) void {
    std.debug.panic("GLFW error ({}): {}\n", err, description);
}

extern fn handleKey(
    window: ?*glfw.GLFWwindow,
    key: c_int,
    scancode: c_int,
    action: c_int,
    mods: c_int,
) void {
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
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 6);
    // glfw.glfwWindowHint(glfw.GLFW_OPENGL_FORWARD_COMPAT, glad.GL_TRUE);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_DEBUG_CONTEXT, glad.GL_TRUE);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);
    // glfw.glfwWindowHint(glfw.GLFW_DEPTH_BITS, 0);
    // glfw.glfwWindowHint(glfw.GLFW_STENCIL_BITS, 8);
    // glfw.glfwWindowHint(glfw.GLFW_RESIZABLE, glad.GL_FALSE);

    var window = glfw.glfwCreateWindow(1280, 720, "MView", null, null) orelse {
        std.debug.panic("unable to create window\n");
    };
    defer glfw.glfwDestroyWindow(window);

    glfw.glfwMakeContextCurrent(window);
    const loaded = glad.gladLoadGLLoader(glfw.glfwGetProcAddress);
    std.debug.warn("loaded: {}\n", loaded);
    glfw.glfwSwapInterval(1);

    const gl_version: [*:0]const u8 = glfw.glGetString(glfw.GL_VERSION);
    const gl_vendor: [*:0]const u8 = glfw.glGetString(glfw.GL_VENDOR);
    std.debug.warn("GL version: {s}\n", gl_version);
    std.debug.warn("GL vendor: {s}\n", gl_vendor);

    _ = glfw.glfwSetKeyCallback(window, handleKey);
    var width: c_int = undefined;
    var height: c_int = undefined;
    glfw.glfwGetFramebufferSize(window, &width, &height);
    std.debug.warn("viewport: {}x{}\n", width, height);

    var vertices = [_]f32{ -0.5, -0.5, 0.5, 0.5, 0.5, -0.5 };
    var vertex_buffer: glad.GLuint = undefined;
    glad.glGenBuffers(1, &vertex_buffer);
    printGlError(false, "vertex genbuffer", true);
    glad.glBindBuffer(glad.GL_ARRAY_BUFFER, vertex_buffer);
    printGlError(false, "vertex bindbuffer", true);
    glad.glBufferData(
        glad.GL_ARRAY_BUFFER,
        @sizeOf(f32) * 6,
        &vertices,
        glad.GL_STATIC_DRAW,
    );
    printGlError(false, "vertex bufferdata", true);

    var vertex_array_object: glad.GLuint = undefined;
    glad.glGenVertexArrays(1, &vertex_array_object);
    printGlError(false, "gen vertex array object", true);
    glad.glBindVertexArray(vertex_array_object);
    printGlError(false, "bind vertex array object", true);
    defer glad.glDeleteVertexArrays(1, &vertex_array_object);

    glad.glEnableVertexAttribArray(0);
    printGlError(false, "vertex enable attrib array", true);
    glad.glVertexAttribPointer(
        0,
        2,
        glad.GL_FLOAT,
        glad.GL_FALSE,
        2 * @sizeOf(f32),
        null,
    );
    printGlError(false, "vertex attribpointer", true);

    var shader = try createShader(vertex_shader_source, fragment_shader_source);
    printGlError(false, "create shaders", true);
    glad.glUseProgram(shader);
    printGlError(false, "use shaders", true);
    defer glad.glDeleteProgram(shader);

    var gl_error: c_uint = glad.glGetError();
    std.debug.warn("gl_error before loop: {}\n", gl_error);

    while (glfw.glfwWindowShouldClose(window) == glad.GL_FALSE) {
        glad.glClear(glad.GL_COLOR_BUFFER_BIT);
        printGlError(false, "clear", true);

        glad.glDrawArrays(glad.GL_TRIANGLES, 0, 3);
        printGlError(false, "drawArrays", true);

        glfw.glfwSwapBuffers(window);

        glfw.glfwPollEvents();
    }
}

fn printGlError(
    comptime warn_on_no_error: bool,
    comptime label: []const u8,
    comptime panic_on_error: bool,
) void {
    var gl_error = glad.glGetError();
    const is_end = mem.eql(u8, label, "end");
    if (!is_end) {
        if (gl_error != glad.GL_NO_ERROR) {
            std.debug.warn("{} is end?: {}", label, is_end);
            std.debug.warn("\n\t");
        } else if (warn_on_no_error) {
            std.debug.warn("{}: no error\n", label);
        }
        switch (gl_error) {
            glad.GL_INVALID_ENUM => std.debug.warn("GL error: invalid enum\n"),
            glad.GL_INVALID_VALUE => std.debug.warn("GL error: invalid value\n"),
            glad.GL_INVALID_OPERATION => std.debug.warn("GL error: invalid operation\n"),
            glad.GL_INVALID_FRAMEBUFFER_OPERATION => std.debug.warn("GL error: invalid fb op\n"),
            glad.GL_OUT_OF_MEMORY => std.debug.warn("GL error: out of memory\n"),
            glad.GL_STACK_UNDERFLOW => std.debug.warn("GL error: stack underflow\n"),
            glad.GL_STACK_OVERFLOW => std.debug.warn("GL error: stack overflow\n"),
            glad.GL_NO_ERROR => {},
            else => unreachable,
        }
        if (gl_error != glad.GL_NO_ERROR and panic_on_error) std.process.exit(1);
    }
}

fn createShader(vertex_shader: []const u8, fragment_shader: []const u8) !glad.GLuint {
    var program = glad.glCreateProgram();
    var vs = try compileShader(vertex_shader, glad.GL_VERTEX_SHADER, "vertex");
    var fs = try compileShader(fragment_shader, glad.GL_FRAGMENT_SHADER, "fragment");

    glad.glAttachShader(program, vs);
    glad.glAttachShader(program, fs);
    glad.glLinkProgram(program);
    glad.glValidateProgram(program);

    glad.glDeleteShader(vs);
    glad.glDeleteShader(fs);

    return program;
}

fn compileShader(source: []const u8, kind: glad.GLenum, name: []const u8) !glad.GLuint {
    const id = glad.glCreateShader(kind);
    const source_ptr: ?[*]const u8 = source.ptr;
    glad.glShaderSource(id, 1, &source_ptr, null);
    glad.glCompileShader(id);

    var ok: glad.GLint = undefined;
    glad.glGetShaderiv(id, glad.GL_COMPILE_STATUS, &ok);
    if (ok != 0) return id;

    var error_size: glad.GLint = undefined;
    glad.glGetShaderiv(id, glad.GL_INFO_LOG_LENGTH, &error_size);

    const message = try c_allocator.alloc(u8, @intCast(usize, error_size));
    var message_ptr: [*:0]u8 = @ptrCast([*:0]u8, message.ptr);
    glad.glGetShaderInfoLog(id, error_size, &error_size, message_ptr);
    std.debug.panic("Error compiling {s} shader:\n{}\n", name, message);
}

var c_allocator = std.heap.c_allocator;

// \\uniform mat4 MVP;
// \\
const vertex_shader_source =
    \\#version 330 core
    \\
    \\layout(location = 0) in vec4 position;
    \\
    \\void main(void) {
    \\    gl_Position = position;
    \\}
;

const fragment_shader_source =
    \\#version 330 core
    \\
    \\layout(location = 0) out vec4 color;
    \\
    \\void main(void) {
    \\    color = vec4(1.0, 0.0, 0.0, 1.0);
    \\}
;
