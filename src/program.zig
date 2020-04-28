const std = @import("std");

const glad = @import("./glad.zig");
const math3d = @import("xq3d").math3d;

pub const Program = struct {
    const Self = @This();

    id: glad.GLuint,
    vertex_shader: VertexShader,
    fragment_shader: FragmentShader,

    pub fn create(vertex_source: []const u8, fragment_source: []const u8) !Self {
        var program_id = glad.glCreateProgram();

        var vertex_shader = try VertexShader.create(vertex_source);
        var fragment_shader = try FragmentShader.create(fragment_source);

        var self = Self{
            .id = program_id,
            .vertex_shader = vertex_shader,
            .fragment_shader = fragment_shader,
        };

        self.attachShader(vertex_shader.id);
        self.attachShader(fragment_shader.id);
        glad.glLinkProgram(program_id);
        glad.glValidateProgram(program_id);

        glad.glDeleteShader(vertex_shader.id);
        glad.glDeleteShader(fragment_shader.id);

        return self;
    }

    fn use(self: Self) void {
        glad.glUseProgram(self.id);
    }

    fn delete(self: Self) void {
        glad.glDeleteProgram(self.id);
    }

    fn setUniform4f(self: Self, name: [*:0]const u8, f1: f32, f2: f32, f3: f32, f4: f32) void {
        const location = self.uniformLocation(name);
        glad.glUniform4f(location, f1, f2, f3, f4);
    }

    fn setUniformMat4(self: Self, name: [*:0]const u8, mat4: math3d.Mat4) void {
        const location = self.uniformLocation(name);
        glad.glUniformMatrix4fv(location, 1, glad.GL_TRUE, &mat4.fields[0]);
    }

    fn uniformLocation(self: Self, uniform_name: [*:0]const u8) c_int {
        return glad.glGetUniformLocation(self.id, uniform_name);
    }

    fn attachShader(self: Self, shader_id: glad.GLuint) void {
        glad.glAttachShader(self.id, shader_id);
    }
};

const VertexShader = struct {
    const Self = @This();

    id: glad.GLuint,
    source: []const u8,

    pub fn create(source: []const u8) !Self {
        var id = try compileShader(source, glad.GL_VERTEX_SHADER, "vertex");

        return Self{ .id = id, .source = source };
    }
};

const FragmentShader = struct {
    const Self = @This();

    id: glad.GLuint,
    source: []const u8,

    pub fn create(source: []const u8) !Self {
        var id = try compileShader(source, glad.GL_FRAGMENT_SHADER, "fragment");

        return Self{ .id = id, .source = source };
    }
};

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
    std.debug.panic("Error compiling {s} shader:\n{}\n", .{ name, message });
}

var c_allocator = std.heap.c_allocator;
