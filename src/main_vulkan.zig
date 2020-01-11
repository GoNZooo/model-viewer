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

extern fn errorCallback(err: c_int, description: [*c]const u8) void {
    var message: [*:0]const u8 = description;
    std.debug.panic("GLFW error ({}): {s}\n", .{ err, message });
}

extern fn handleKey(
    window: ?*c.GLFWwindow,
    key: c_int,
    scancode: c_int,
    action: c_int,
    mods: c_int,
) void {
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
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE);
    var window = c.glfwCreateWindow(1280, 720, "MView", null, null) orelse {
        std.debug.panic("unable to create window\n", .{});
    };
    defer c.glfwDestroyWindow(window);

    var context = try Context.init(heap.page_allocator, window, needs_discrete_gpu);
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

        try drawFrame(context, &current_frame);
    }

    _ = c.vkDeviceWaitIdle(context.logical_device);
}

fn drawFrame(context: Context, current_frame: *u64) !void {
    defer current_frame.* += 1;
    const sync_objects_index = current_frame.* % context.sync_objects.len;
    var sync_objects = context.sync_objects[sync_objects_index];
    _ = c.vkWaitForFences(
        context.logical_device,
        1,
        &sync_objects.fence,
        c.VK_TRUE,
        std.math.maxInt(u64),
    );
    var image_index: u32 = undefined;
    _ = c.vkAcquireNextImageKHR(
        context.logical_device,
        context.swap_chain,
        std.math.maxInt(u32),
        sync_objects.image_available_semaphore,
        null,
        &image_index,
    );
    if (sync_objects.in_flight != null) {
        debug.warn("waiting for in flight semaphore\n", .{});
        _ = c.vkWaitForFences(
            context.logical_device,
            1,
            &sync_objects.in_flight,
            c.VK_TRUE,
            std.math.maxInt(u64),
        );
    }
    sync_objects.in_flight = sync_objects.fence;
    debug.assert(image_index < context.command_buffers.len);

    const signal_semaphores = [_]c.VkSemaphore{sync_objects.render_finished_semaphore};
    const wait_semaphores = [_]c.VkSemaphore{sync_objects.image_available_semaphore};
    const wait_stages = [_]c.VkPipelineStageFlags{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
    const submit_info = c.VkSubmitInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = wait_semaphores.len,
        .pWaitSemaphores = &wait_semaphores,
        .pWaitDstStageMask = &wait_stages,
        .commandBufferCount = 1,
        .pCommandBuffers = &context.command_buffers[image_index],
        .signalSemaphoreCount = signal_semaphores.len,
        .pSignalSemaphores = &signal_semaphores,
        .pNext = null,
    };

    _ = c.vkResetFences(context.logical_device, 1, &sync_objects.in_flight);
    if (c.vkQueueSubmit(
        context.queue,
        1,
        &submit_info,
        sync_objects.in_flight,
    ) != c.VkResult.VK_SUCCESS) {
        return error.UnableToSubmitQueue;
    }

    const swap_chains = [_]c.VkSwapchainKHR{context.swap_chain};
    const present_info = c.VkPresentInfoKHR{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &wait_semaphores,
        .swapchainCount = swap_chains.len,
        .pSwapchains = &swap_chains,
        .pImageIndices = &image_index,
        .pResults = null,
        .pNext = null,
    };

    _ = c.vkQueuePresentKHR(context.present_queue, &present_info);

    _ = c.vkQueueWaitIdle(context.present_queue);
}
