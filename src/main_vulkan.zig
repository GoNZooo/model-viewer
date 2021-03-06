const std = @import("std");
const mem = std.mem;
const heap = std.heap;
const process = std.process;
const debug = std.debug;

const obj = @import("./obj.zig");
const vulkan_utilities = @import("vulkan/utilities.zig");
const Context = @import("vulkan/context.zig").Context;

const Program = @import("./program.zig").Program;

const c = @import("./c.zig");

fn errorCallback(err: c_int, description: [*c]const u8) callconv(.C) void {
    var message: [*:0]const u8 = description;
    std.debug.panic("GLFW error ({}): {s}\n", .{ err, message });
}

fn handleKey(
    window: ?*c.GLFWwindow,
    key: c_int,
    scancode: c_int,
    action: c_int,
    mods: c_int,
) callconv(.C) void {
    if (action != c.GLFW_PRESS) return;

    switch (key) {
        c.GLFW_KEY_ESCAPE, c.GLFW_KEY_Q => {
            c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
        },
        else => {},
    }
}

pub fn main() anyerror!void {
    var arg_iterator = process.args();
    const needs_discrete_gpu = needs: {
        if (arg_iterator.next(heap.page_allocator)) |arg| {
            if (mem.eql(u8, try arg, "yes")) break :needs true;
        }

        break :needs false;
    };
    debug.warn("needs_discrete_gpu={}\n", .{needs_discrete_gpu});

    _ = c.glfwSetErrorCallback(errorCallback);
    if (c.glfwInit() == c.GLFW_FALSE) @panic("glfwInit() failed\n");
    defer c.glfwTerminate();
    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    var window = c.glfwCreateWindow(1280, 720, "MView", null, null) orelse {
        std.debug.panic("unable to create window\n", .{});
    };
    _ = c.glfwSetKeyCallback(window, handleKey);

    var context = try Context.init(heap.page_allocator, window, needs_discrete_gpu);
    _ = c.glfwSetWindowUserPointer(window, &context);
    defer context.deinit();
    // std.debug.warn("context: {}\n", .{context});
    std.debug.warn("required extensions: {}\n", .{context.extensions.required.len});
    for (context.extensions.required) |extension| {
        std.debug.warn("\t{s}\n", .{extension});
    }
    std.debug.warn("available extensions: {}\n", .{context.extensions.available.len});
    for (context.extensions.available) |extension| {
        var extension_name: [*:0]const u8 = @ptrCast([*:0]const u8, &extension.extensionName);
        std.debug.warn("\t{s}\n", .{extension_name});
    }
    std.debug.warn("available layers: {}\n", .{context.layers.len});
    for (context.layers) |layer| {
        var layer_name: [*:0]const u8 = @ptrCast([*:0]const u8, &layer.layerName);
        std.debug.warn("\t{s}\n", .{layer_name});
    }

    std.debug.warn("queue: {}\n", .{context.queue});
    std.debug.warn("present_queue: {}\n", .{context.present_queue});
    std.debug.warn("surface: {}\n", .{context.surface});

    var current_frame: u64 = 0;
    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        // glfw.glfwSwapBuffers(window);
        c.glfwPollEvents();

        try context.drawFrame(&current_frame);
    }

    _ = c.vkDeviceWaitIdle(context.logical_device);
}
