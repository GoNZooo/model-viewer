const std = @import("std");
const fs = std.fs;
const mem = std.mem;

const c = @import("../c.zig");

pub fn readFile(allocator: *mem.Allocator, filepath: []const u8) ![]const u8 {
    const cwd = fs.cwd();
    const file_data = try cwd.readFileAlloc(allocator, filepath, max_file_size);

    return file_data;
}

pub fn createShaderModule(device: c.VkDevice, shader_code: []const u8) !c.VkShaderModule {
    var create_info = c.VkShaderModuleCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = shader_code.len,
        .pCode = @ptrCast([*c]const u32, @alignCast(@alignOf([*c]const u32), shader_code.ptr)),
        .pNext = null,
        .flags = 0,
    };

    var shader_module: c.VkShaderModule = undefined;
    if (c.vkCreateShaderModule(
        device,
        &create_info,
        null,
        &shader_module,
    ) != c.VkResult.VK_SUCCESS) {
        return error.UnableToCreateShaderModule;
    }

    return shader_module;
}

const max_file_size = 1024 * 1024;
