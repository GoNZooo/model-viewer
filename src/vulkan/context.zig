const std = @import("std");
const mem = std.mem;

const c = @import("../c.zig");

pub const ExtensionInfo = struct {
    required: []const []const u8,
    available: []c.VkExtensionProperties,
    extensions_start: [*c]const [*c]const u8,
};

const QueueFamilyIndices = struct {
    graphics_family: ?u32,
    present_family: ?u32,
};

pub const Context = struct {
    const Self = @This();

    physical_device: c.VkPhysicalDevice,
    logical_device: c.VkDevice,
    extensions: ExtensionInfo,
    device_extensions: ExtensionInfo,
    layers: []c.VkLayerProperties,
    instance: c.VkInstance,
    queue: c.VkQueue,
    present_queue: c.VkQueue,
    surface: c.VkSurfaceKHR,

    _allocator: *mem.Allocator,

    pub fn init(allocator: *mem.Allocator, window: *c.GLFWwindow) !Self {
        var instance: c.VkInstance = undefined;
        var extensions: ExtensionInfo = undefined;
        var layers: []c.VkLayerProperties = undefined;
        try initVulkan(allocator, &instance, &extensions, &layers);

        var surface: c.VkSurfaceKHR = undefined;
        if (c.glfwCreateWindowSurface(instance, window, null, &surface) != c.VK_SUCCESS) {
            return error.UnableToCreateSurface;
        }

        var device_extensions = ExtensionInfo{
            .required = required_device_extensions,
            .available = undefined,
            .extensions_start = undefined,
        };
        var physical_device = try pickPhysicalDevice(
            allocator,
            instance,
            surface,
            &device_extensions,
        );
        if (physical_device == null) return error.NoPhysicalDevice;

        var queue: c.VkQueue = undefined;
        var present_queue: c.VkQueue = undefined;
        var logical_device = try createLogicalDevice(
            allocator,
            physical_device,
            &queue,
            &present_queue,
            surface,
            device_extensions,
        );
        if (logical_device == null) return error.NoLogicalDevice;

        return Self{
            .instance = instance,
            .physical_device = physical_device,
            .logical_device = logical_device,
            .extensions = extensions,
            .device_extensions = device_extensions,
            .layers = layers,
            .queue = queue,
            .present_queue = present_queue,
            .surface = surface,
            ._allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        c.vkDestroyDevice(self.logical_device, null);
        c.vkDestroySurfaceKHR(self.instance, self.surface, null);
        c.vkDestroyInstance(self.instance, null);
    }
};

fn initVulkan(
    allocator: *mem.Allocator,
    instance: *c.VkInstance,
    extensions: *ExtensionInfo,
    layers: *[]c.VkLayerProperties,
) !void {
    var application_info = c.VkApplicationInfo{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "MView",
        .applicationVersion = make_version(1, 0, 0),
        .pEngineName = "No Engine",
        .engineVersion = make_version(1, 0, 0),
        .apiVersion = make_version(1, 0, 0),
        .pNext = null,
    };

    extensions.* = try getExtensions(allocator);
    layers.* = try getLayers(allocator);

    var create_info = c.VkInstanceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &application_info,
        .enabledExtensionCount = @intCast(u32, extensions.required.len),
        .ppEnabledExtensionNames = extensions.extensions_start,
        .ppEnabledLayerNames = &validation_layers[0],
        .enabledLayerCount = validation_layers.len,
        .pNext = null,
        .flags = 0,
    };

    if (c.vkCreateInstance(&create_info, null, instance) != c.VK_SUCCESS) {
        return error.UnableToCreateVulkanInstance;
    }
}

fn make_version(major: u32, minor: u32, patch: u32) u32 {
    return (major << 22) | (minor << 12) | patch;
}
pub fn getExtensions(allocator: *mem.Allocator) !ExtensionInfo {
    var required_extensions_count: u32 = undefined;
    var vulkan_extension_count: u32 = undefined;
    var glfw_extensions_return: [*c]const [*c]const u8 = 0;

    glfw_extensions_return = c.glfwGetRequiredInstanceExtensions(&required_extensions_count);
    _ = c.vkEnumerateInstanceExtensionProperties(null, &vulkan_extension_count, null);
    var vulkan_extensions = try allocator.alloc(c.VkExtensionProperties, vulkan_extension_count);
    _ = c.vkEnumerateInstanceExtensionProperties(
        null,
        &vulkan_extension_count,
        vulkan_extensions.ptr,
    );

    var required_extensions = try allocator.alloc([]u8, required_extensions_count);
    var written_extensions: usize = 0;
    while (written_extensions < required_extensions_count) : (written_extensions += 1) {
        var single_ext_ptr: [*c]const u8 = glfw_extensions_return[written_extensions];
        var i: usize = 0;
        var s = [_]u8{0} ** 64;
        while (single_ext_ptr.* != 0) : (single_ext_ptr += 1) {
            s[i] = single_ext_ptr.*;
            i += 1;
        }
        var allocated_string = try allocator.alloc(u8, i);
        mem.copy(u8, allocated_string, s[0..i]);
        required_extensions[written_extensions] = allocated_string;
    }

    return ExtensionInfo{
        .required = required_extensions,
        .available = vulkan_extensions,
        .extensions_start = glfw_extensions_return,
    };
}

pub fn getLayers(allocator: *mem.Allocator) ![]c.VkLayerProperties {
    var layer_count: u32 = undefined;
    _ = c.vkEnumerateInstanceLayerProperties(&layer_count, null);
    var layers = try std.heap.page_allocator.alloc(c.VkLayerProperties, layer_count);
    _ = c.vkEnumerateInstanceLayerProperties(&layer_count, layers.ptr);

    return layers;
}

pub fn findQueueFamilies(
    allocator: *mem.Allocator,
    device: c.VkPhysicalDevice,
    surface: c.VkSurfaceKHR,
) !QueueFamilyIndices {
    var indices: QueueFamilyIndices = undefined;

    var queue_family_count: u32 = 0;
    _ = c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);
    var queue_families = try allocator.alloc(c.VkQueueFamilyProperties, queue_family_count);
    _ = c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, queue_families.ptr);
    var present_support: c.VkBool32 = undefined;

    for (queue_families) |queue_family, i| {
        _ = c.vkGetPhysicalDeviceSurfaceSupportKHR(
            device,
            @intCast(u32, i),
            surface,
            &present_support,
        );
        const masked_family_flags = queue_family.queueFlags &
            @as(u32, @enumToInt(c.VkQueueFlagBits.VK_QUEUE_GRAPHICS_BIT));
        if (masked_family_flags != 0 and present_support != 0) {
            indices.graphics_family = @intCast(u32, i);
            indices.present_family = @intCast(u32, i);
        }
    }

    return indices;
}

pub fn createLogicalDevice(
    allocator: *mem.Allocator,
    physical_device: c.VkPhysicalDevice,
    queue: *c.VkQueue,
    present_queue: *c.VkQueue,
    surface: c.VkSurfaceKHR,
    device_extensions: ExtensionInfo,
) !c.VkDevice {
    var queue_indices = try findQueueFamilies(allocator, physical_device, surface);
    var queue_families = r: {
        if (queue_indices.graphics_family.? == queue_indices.present_family.?) {
            break :r &[_]u32{queue_indices.present_family.?};
        } else {
            break :r &[_]u32{ queue_indices.graphics_family.?, queue_indices.present_family.? };
        }
    };
    var queue_priority: f32 = 1.0;
    var queue_create_infos = try allocator.alloc(c.VkDeviceQueueCreateInfo, queue_families.len);
    for (queue_families) |qf, i| {
        queue_create_infos[i] = c.VkDeviceQueueCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = null,
            .queueFamilyIndex = qf,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
            .flags = 0,
        };
    }

    var device_features = zeroInit(c.VkPhysicalDeviceFeatures);
    var device_create_info = zeroInit(c.VkDeviceCreateInfo);
    device_create_info.sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    device_create_info.pQueueCreateInfos = queue_create_infos.ptr;
    device_create_info.queueCreateInfoCount = @intCast(u32, queue_create_infos.len);
    device_create_info.pEnabledFeatures = &device_features;
    device_create_info.enabledExtensionCount = @intCast(u32, device_extensions.required.len);
    device_create_info.ppEnabledExtensionNames = device_extensions.extensions_start;

    var logical_device: c.VkDevice = undefined;

    if (c.vkCreateDevice(
        physical_device,
        &device_create_info,
        null,
        &logical_device,
    ) != c.VK_SUCCESS) {
        return error.UnableToCreateLogicalDevice;
    }

    c.vkGetDeviceQueue(logical_device, queue_indices.graphics_family.?, 0, queue);
    c.vkGetDeviceQueue(logical_device, queue_indices.present_family.?, 0, present_queue);

    return logical_device;
}

pub fn pickPhysicalDevice(
    allocator: *mem.Allocator,
    instance: c.VkInstance,
    surface: c.VkSurfaceKHR,
    device_extensions: *ExtensionInfo,
) !c.VkPhysicalDevice {
    var physical_device: c.VkPhysicalDevice = null;
    var device_count: u32 = 0;
    _ = c.vkEnumeratePhysicalDevices(instance, &device_count, null);

    if (device_count == 0) return error.NoPhysicalDevices;

    var physical_devices = try allocator.alloc(c.VkPhysicalDevice, device_count);
    _ = c.vkEnumeratePhysicalDevices(instance, &device_count, physical_devices.ptr);

    for (physical_devices) |device| {
        if (try isDeviceSuitable(allocator, device, surface, device_extensions)) {
            physical_device = device;
            break;
        }
    }

    return physical_device;
}

pub fn zeroInit(comptime T: type) T {
    var bytes = [_]u8{0} ** @sizeOf(T);

    return mem.bytesToValue(T, &bytes);
}

fn isDeviceSuitable(
    allocator: *mem.Allocator,
    device: c.VkPhysicalDevice,
    surface: c.VkSurfaceKHR,
    device_extensions: *ExtensionInfo,
) !bool {
    var device_properties: c.VkPhysicalDeviceProperties = undefined;
    var device_features: c.VkPhysicalDeviceFeatures = undefined;

    _ = c.vkGetPhysicalDeviceProperties(device, &device_properties);
    _ = c.vkGetPhysicalDeviceFeatures(device, &device_features);

    const queue_families = try findQueueFamilies(allocator, device, surface);
    const device_is_discrete_gpu = device_properties.deviceType ==
        c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU;
    const has_graphics_family = queue_families.graphics_family != null;
    const has_present_family = queue_families.present_family != null;
    const has_device_extension_support = hasDeviceExtensionSupport(
        allocator,
        device,
        device_extensions,
    );

    return device_is_discrete_gpu and has_graphics_family and has_present_family and
        has_device_extension_support;
}

fn hasDeviceExtensionSupport(
    allocator: *mem.Allocator,
    physical_device: c.VkPhysicalDevice,
    device_extensions: *ExtensionInfo,
) !bool {
    var extension_count: u32 = 0;
    _ = c.vkEnumerateDeviceExtensionProperties(physical_device, null, &extension_count, null);
    var available_extensions = try allocator.alloc(c.VkExtensionProperties, extension_count);
    _ = c.vkEnumerateDeviceExtensionProperties(
        physical_device,
        null,
        &extension_count,
        available_extensions.ptr,
    );
    var extensions_start = required_device_extensions_c;
    device_extensions.available = available_extensions;
    device_extensions.extensions_start = extensions_start;

    var found_all = true;
    for (device_extensions.required) |extension_name| {
        if (!hasExtension(extension_name, available_extensions)) {
            std.debug.warn("could not find required extension: {}\n", .{extension_name});
            found_all = false;
            break;
        }
        std.debug.warn("found required extension: {}\n", .{extension_name});
    }

    return found_all;
}

fn hasExtension(extension_name: []const u8, extension_properties: []c.VkExtensionProperties) bool {
    for (extension_properties) |extension| {
        if (mem.eql(u8, extension_name, extension.extensionName[0..extension_name.len])) {
            return true;
        }
    }

    return false;
}

const khronos_validation = "VK_LAYER_KHRONOS_validation";

const validation_layers = [_][*:0]const u8{khronos_validation};

const required_device_extensions: []const []const u8 = &[_][]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME[0..16],
};
const required_device_extensions_c: [*c]const [*c]const u8 = &[_][*c]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
};
