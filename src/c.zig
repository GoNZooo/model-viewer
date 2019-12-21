pub usingnamespace @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", {});
    // @cDefine("VK_USE_PLATFORM_WIN32_KHR", {});
    // @cDefine("GLFW_EXPOSE_NATIVE_WIN32", {});
    @cInclude("GLFW/glfw3.h");
    // @cInclude("GLFW/glfw3native.h");
});
