const std = @import("std");
const mem = std.mem;
const debug = std.debug;

const spv = @import("./spv.zig");
const c = @import("../c.zig");

pub const ExtensionInfo = struct {
    required: []const []const u8,
    available: []c.VkExtensionProperties,
    extensions_start: [*c]const [*c]const u8,
    _allocator: *mem.Allocator,

    fn deinit(self: *ExtensionInfo) void {
        self._allocator.free(self.required);
        self._allocator.free(self.available);
    }
};

const QueueFamilyIndices = struct {
    graphics_family: ?u32,
    present_family: ?u32,
};

const SwapChainSupportDetails = struct {
    capabilities: c.VkSurfaceCapabilitiesKHR,
    formats: []c.VkSurfaceFormatKHR,
    present_modes: []c.VkPresentModeKHR,
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
    swap_chain_support_details: SwapChainSupportDetails,
    swap_chain: c.VkSwapchainKHR,
    swap_chain_images: []c.VkImage,
    surface_format: c.VkSurfaceFormatKHR,
    swap_extent: c.VkExtent2D,
    swap_chain_image_format: c.VkFormat,
    image_views: []c.VkImageView,
    queue_create_infos: []c.VkDeviceQueueCreateInfo,
    vertex_shader_module: c.VkShaderModule,
    fragment_shader_module: c.VkShaderModule,

    _allocator: *mem.Allocator,

    pub fn init(allocator: *mem.Allocator, window: *c.GLFWwindow) !Self {
        var instance: c.VkInstance = undefined;
        var extensions: ExtensionInfo = undefined;
        var layers: []c.VkLayerProperties = undefined;
        try initVulkan(allocator, &instance, &extensions, &layers);

        var surface: c.VkSurfaceKHR = undefined;
        if (c.glfwCreateWindowSurface(instance, window, null, &surface) != c.VkResult.VK_SUCCESS) {
            return error.UnableToCreateSurface;
        }

        var device_extensions = ExtensionInfo{
            .required = required_device_extensions,
            .available = undefined,
            .extensions_start = undefined,
            ._allocator = allocator,
        };

        var swap_chain_support_details: SwapChainSupportDetails = undefined;

        var surface_format: c.VkSurfaceFormatKHR = undefined;
        var present_mode: c.VkPresentModeKHR = undefined;
        var swap_extent: c.VkExtent2D = undefined;

        var physical_device = try pickPhysicalDevice(
            allocator,
            instance,
            surface,
            &swap_chain_support_details,
            &device_extensions,
            &surface_format,
            &present_mode,
            &swap_extent,
        );
        if (physical_device == null) return error.NoPhysicalDevice;

        var queue: c.VkQueue = undefined;
        var present_queue: c.VkQueue = undefined;
        var queue_create_infos: []c.VkDeviceQueueCreateInfo = undefined;
        var logical_device = try createLogicalDevice(
            allocator,
            physical_device,
            &queue,
            &present_queue,
            surface,
            device_extensions,
            &queue_create_infos,
        );
        if (logical_device == null) return error.NoLogicalDevice;

        var swap_chain_image_format: c.VkFormat = undefined;

        var swap_chain = try createSwapChain(
            allocator,
            swap_chain_support_details,
            surface_format,
            present_mode,
            swap_extent,
            surface,
            physical_device,
            logical_device,
            &swap_chain_image_format,
        );
        // This crashes compilation, "broken LLVM module found: Duplicate integer as switch case"
        // std.debug.warn("surface_format: {}\n", .{surface_format});

        var swap_chain_images = try getSwapChainImages(allocator, logical_device, swap_chain);
        var image_views = try createImageViews(
            allocator,
            swap_chain_images,
            swap_chain_image_format,
            logical_device,
        );

        var vertex_shader_module: c.VkShaderModule = undefined;
        var fragment_shader_module: c.VkShaderModule = undefined;
        try createGraphicsPipeline(
            allocator,
            logical_device,
            &vertex_shader_module,
            &fragment_shader_module,
        );

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
            .swap_chain_support_details = swap_chain_support_details,
            .swap_chain = swap_chain,
            .swap_chain_images = swap_chain_images,
            .surface_format = surface_format,
            .swap_extent = swap_extent,
            .swap_chain_image_format = swap_chain_image_format,
            .image_views = image_views,
            .queue_create_infos = queue_create_infos,
            .vertex_shader_module = vertex_shader_module,
            .fragment_shader_module = fragment_shader_module,
            ._allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        c.vkDestroyShaderModule(self.logical_device, self.vertex_shader_module, null);
        c.vkDestroyShaderModule(self.logical_device, self.fragment_shader_module, null);
        for (self.image_views) |view| {
            c.vkDestroyImageView(self.logical_device, view, null);
        }
        c.vkDestroySwapchainKHR(self.logical_device, self.swap_chain.?, null);
        c.vkDestroyDevice(self.logical_device, null);
        c.vkDestroySurfaceKHR(self.instance, self.surface, null);
        c.vkDestroyInstance(self.instance, null);
        self._allocator.free(self.image_views);
        self._allocator.free(self.swap_chain_images);
        self._allocator.free(self.layers);
        self._allocator.free(self.queue_create_infos);
        self.extensions.deinit();
    }
};

fn initVulkan(
    allocator: *mem.Allocator,
    instance: *c.VkInstance,
    extensions: *ExtensionInfo,
    layers: *[]c.VkLayerProperties,
) !void {
    var application_info = c.VkApplicationInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
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
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &application_info,
        .enabledExtensionCount = @intCast(u32, extensions.required.len),
        .ppEnabledExtensionNames = extensions.extensions_start,
        .ppEnabledLayerNames = &validation_layers[0],
        .enabledLayerCount = validation_layers.len,
        .pNext = null,
        .flags = 0,
    };

    if (c.vkCreateInstance(&create_info, null, instance) != c.VkResult.VK_SUCCESS) {
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
        ._allocator = allocator,
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
    defer allocator.free(queue_families);
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
    queue_create_infos: *[]c.VkDeviceQueueCreateInfo,
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
    queue_create_infos.* = try allocator.alloc(c.VkDeviceQueueCreateInfo, queue_families.len);
    // defer allocator.free(queue_create_infos);
    for (queue_families) |qf, i| {
        queue_create_infos.*[i] = c.VkDeviceQueueCreateInfo{
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = null,
            .queueFamilyIndex = qf,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
            .flags = 0,
        };
    }

    var device_features = zeroInit(c.VkPhysicalDeviceFeatures);
    var device_create_info = zeroInit(c.VkDeviceCreateInfo);
    device_create_info.sType = c.VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
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
    ) != c.VkResult.VK_SUCCESS) {
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
    swap_chain_support_details: *SwapChainSupportDetails,
    device_extensions: *ExtensionInfo,
    surface_format: *c.VkSurfaceFormatKHR,
    present_mode: *c.VkPresentModeKHR,
    swap_extent: *c.VkExtent2D,
) !c.VkPhysicalDevice {
    var physical_device: c.VkPhysicalDevice = null;
    var device_count: u32 = 0;
    _ = c.vkEnumeratePhysicalDevices(instance, &device_count, null);

    if (device_count == 0) return error.NoPhysicalDevices;

    var physical_devices = try allocator.alloc(c.VkPhysicalDevice, device_count);
    defer allocator.free(physical_devices);
    _ = c.vkEnumeratePhysicalDevices(instance, &device_count, physical_devices.ptr);

    for (physical_devices) |device| {
        if (try isDeviceSuitable(
            allocator,
            device,
            surface,
            swap_chain_support_details,
            device_extensions,
            surface_format,
            present_mode,
            swap_extent,
        )) {
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
    swap_chain_support_details: *SwapChainSupportDetails,
    device_extensions: *ExtensionInfo,
    surface_format: *c.VkSurfaceFormatKHR,
    present_mode: *c.VkPresentModeKHR,
    swap_extent: *c.VkExtent2D,
) !bool {
    var device_properties: c.VkPhysicalDeviceProperties = undefined;
    var device_features: c.VkPhysicalDeviceFeatures = undefined;

    _ = c.vkGetPhysicalDeviceProperties(device, &device_properties);
    _ = c.vkGetPhysicalDeviceFeatures(device, &device_features);

    const queue_families = try findQueueFamilies(allocator, device, surface);
    const device_is_discrete_gpu = device_properties.deviceType ==
        c.VkPhysicalDeviceType.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU;
    const has_graphics_family = queue_families.graphics_family != null;
    const has_present_family = queue_families.present_family != null;
    const has_device_extension_support = try hasDeviceExtensionSupport(
        allocator,
        device,
        device_extensions,
    );

    var swap_chain_adequate = false;
    if (has_device_extension_support) {
        swap_chain_support_details.* = try querySwapChainSupport(
            allocator,
            device,
            surface,
            surface_format,
            present_mode,
            swap_extent,
        );
        swap_chain_adequate = swap_chain_support_details.formats.len != 0 and
            swap_chain_support_details.present_modes.len != 0;
    }

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
            debug.warn("could not find required extension: {}\n", .{extension_name});
            found_all = false;
            break;
        }
        debug.warn("found required extension: {}\n", .{extension_name});
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

fn querySwapChainSupport(
    allocator: *mem.Allocator,
    device: c.VkPhysicalDevice,
    surface: c.VkSurfaceKHR,
    surface_format: *c.VkSurfaceFormatKHR,
    present_mode: *c.VkPresentModeKHR,
    swap_extent: *c.VkExtent2D,
) !SwapChainSupportDetails {
    var details: SwapChainSupportDetails = undefined;
    _ = c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &details.capabilities);

    var format_count: u32 = undefined;
    _ = c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, null);
    var formats = try allocator.alloc(c.VkSurfaceFormatKHR, format_count);
    errdefer allocator.free(formats);
    _ = c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, formats.ptr);

    var present_mode_count: u32 = undefined;
    _ = c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, null);
    var present_modes = try allocator.alloc(c.VkPresentModeKHR, present_mode_count);
    _ = c.vkGetPhysicalDeviceSurfacePresentModesKHR(
        device,
        surface,
        &present_mode_count,
        present_modes.ptr,
    );

    details.formats = formats;
    details.present_modes = present_modes;

    surface_format.* = chooseSwapSurfaceFormat(formats);
    present_mode.* = chooseSwapPresentMode(present_modes);
    swap_extent.* = chooseSwapExtent(details.capabilities);

    return details;
}

fn chooseSwapSurfaceFormat(available_formats: []c.VkSurfaceFormatKHR) c.VkSurfaceFormatKHR {
    debug.assert(available_formats.len > 0);
    for (available_formats) |f| {
        if (f.format == c.VkFormat.VK_FORMAT_B8G8R8A8_UNORM and
            f.colorSpace == c.VkColorSpaceKHR.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
        {
            return f;
        }
    }

    return available_formats[0];
}

fn chooseSwapPresentMode(available_present_modes: []c.VkPresentModeKHR) c.VkPresentModeKHR {
    debug.assert(available_present_modes.len > 0);

    for (available_present_modes) |pm| {
        if (pm == c.VkPresentModeKHR.VK_PRESENT_MODE_MAILBOX_KHR) return pm;
    }

    return c.VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR;
}

fn chooseSwapExtent(capabilities: c.VkSurfaceCapabilitiesKHR) c.VkExtent2D {
    if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
        return capabilities.currentExtent;
    } else {
        var actual_extent = c.VkExtent2D{ .width = chosen_width, .height = chosen_height };

        actual_extent.width = std.math.max(
            capabilities.minImageExtent.width,
            std.math.min(capabilities.maxImageExtent.width, actual_extent.width),
        );

        actual_extent.height = std.math.max(
            capabilities.minImageExtent.height,
            std.math.min(capabilities.maxImageExtent.height, actual_extent.height),
        );

        return actual_extent;
    }
}

fn createSwapChain(
    allocator: *mem.Allocator,
    swap_chain_support_details: SwapChainSupportDetails,
    surface_format: c.VkSurfaceFormatKHR,
    present_mode: c.VkPresentModeKHR,
    swap_extent: c.VkExtent2D,
    surface: c.VkSurfaceKHR,
    physical_device: c.VkPhysicalDevice,
    logical_device: c.VkDevice,
    swap_chain_image_format: *c.VkFormat,
) !c.VkSwapchainKHR {
    var image_count = swap_chain_support_details.capabilities.minImageCount + 1;

    if (swap_chain_support_details.capabilities.maxImageCount > 0 and
        image_count > swap_chain_support_details.capabilities.maxImageCount)
    {
        image_count = swap_chain_support_details.capabilities.maxImageCount;
    }

    var create_info = zeroInit(c.VkSwapchainCreateInfoKHR);

    const queue_families = try findQueueFamilies(allocator, physical_device, surface);
    var queue_indices = [_]u32{ queue_families.graphics_family.?, queue_families.present_family.? };

    create_info.sType = c.VkStructureType.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    create_info.surface = surface;
    create_info.minImageCount = image_count;
    create_info.imageFormat = surface_format.format;
    create_info.imageColorSpace = surface_format.colorSpace;
    create_info.imageExtent = swap_extent;
    create_info.imageArrayLayers = 1;
    create_info.imageUsage = @enumToInt(c.VkImageUsageFlagBits.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT);

    swap_chain_image_format.* = surface_format.format;

    if (queue_families.graphics_family.? != queue_families.present_family.?) {
        debug.warn("graphics & present family different\n", .{});
        create_info.imageSharingMode = c.VkSharingMode.VK_SHARING_MODE_CONCURRENT;
        create_info.queueFamilyIndexCount = 2;
        create_info.pQueueFamilyIndices = &queue_indices[0];
    } else {
        debug.warn("graphics & present family NOT different\n", .{});
        create_info.imageSharingMode = c.VkSharingMode.VK_SHARING_MODE_EXCLUSIVE;
        // create_info.queueFamilyIndexCount = 0;
        // create_info.pQueueFamilyIndices = null;
    }

    create_info.preTransform = swap_chain_support_details.capabilities.currentTransform;
    create_info.compositeAlpha = c.VkCompositeAlphaFlagBitsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    create_info.presentMode = present_mode;
    create_info.clipped = c.VK_TRUE;
    // create_info.oldSwapchain = null;

    var swap_chain: c.VkSwapchainKHR = undefined;
    if (c.vkCreateSwapchainKHR(logical_device, &create_info, null, &swap_chain) !=
        c.VkResult.VK_SUCCESS)
    {
        return error.UnableToCreateSwapChain;
    }

    return swap_chain;
}

fn getSwapChainImages(
    allocator: *mem.Allocator,
    logical_device: c.VkDevice,
    swap_chain: c.VkSwapchainKHR,
) ![]c.VkImage {
    var image_count: u32 = undefined;
    _ = c.vkGetSwapchainImagesKHR(logical_device, swap_chain, &image_count, null);
    var images = try allocator.alloc(c.VkImage, image_count);
    _ = c.vkGetSwapchainImagesKHR(logical_device, swap_chain, &image_count, images.ptr);

    return images;
}

fn createImageViews(
    allocator: *mem.Allocator,
    swap_chain_images: []c.VkImage,
    swap_chain_image_format: c.VkFormat,
    device: c.VkDevice,
) ![]c.VkImageView {
    var image_views = try allocator.alloc(c.VkImageView, swap_chain_images.len);

    const component_swizzle_identity = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY;
    for (swap_chain_images) |image, i| {
        var create_info = c.VkImageViewCreateInfo{
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = image,
            .viewType = c.VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
            .format = swap_chain_image_format,
            .components = c.VkComponentMapping{
                .r = component_swizzle_identity,
                .g = component_swizzle_identity,
                .b = component_swizzle_identity,
                .a = component_swizzle_identity,
            },
            .subresourceRange = c.VkImageSubresourceRange{
                .aspectMask = @enumToInt(c.VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT),
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
            .pNext = null,
            .flags = 0,
        };

        if (c.vkCreateImageView(
            device,
            &create_info,
            null,
            &image_views[i],
        ) != c.VkResult.VK_SUCCESS) {
            return error.UnableToCreateImageView;
        }
    }

    return image_views;
}

fn createGraphicsPipeline(
    allocator: *mem.Allocator,
    device: c.VkDevice,
    vertex_shader_module: *c.VkShaderModule,
    fragment_shader_module: *c.VkShaderModule,
) !void {
    const vertex_shader_code = try spv.readFile(allocator, vertex_shader_filename);
    const fragment_shader_code = try spv.readFile(allocator, fragment_shader_filename);

    vertex_shader_module.* = try spv.createShaderModule(device, vertex_shader_code);
    fragment_shader_module.* = try spv.createShaderModule(device, fragment_shader_code);
}

const vertex_shader_filename = "shaders\\vertex.spv";

const fragment_shader_filename = "shaders\\fragment.spv";

const khronos_validation = "VK_LAYER_KHRONOS_validation";

const validation_layers = [_][*:0]const u8{khronos_validation};

const required_device_extensions: []const []const u8 = &[_][]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME[0..16],
};
const required_device_extensions_c: [*c]const [*c]const u8 = &[_][*c]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
};

const chosen_width: u32 = 1280;
const chosen_height: u32 = 720;
