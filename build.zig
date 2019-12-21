const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("model-viewer", "src/main.zig");
    const vulkan_exe = b.addExecutable("model-viewer", "src/main_vulkan.zig");

    exe.addCSourceFile("dependencies/glad/src/glad.c", &[_][]const u8{"-std=c99"});
    exe.addIncludeDir("dependencies/glad/include");
    exe.addIncludeDir("dependencies/glfw/include");

    vulkan_exe.addIncludeDir("dependencies/glfw/include");
    vulkan_exe.addIncludeDir("dependencies/vulkan/Include");

    exe.addLibPath("dependencies/glfw");
    vulkan_exe.addLibPath("dependencies/glfw");
    vulkan_exe.addLibPath("dependencies/vulkan/Lib");

    exe.linkLibC();
    exe.linkSystemLibrary("opengl32");
    exe.linkSystemLibrary("glfw3");
    exe.linkSystemLibrary("shell32");
    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("gdi32");

    vulkan_exe.linkLibC();
    vulkan_exe.linkSystemLibrary("vulkan-1");
    vulkan_exe.linkSystemLibrary("glfw3");
    vulkan_exe.linkSystemLibrary("shell32");
    vulkan_exe.linkSystemLibrary("user32");
    vulkan_exe.linkSystemLibrary("gdi32");

    exe.setBuildMode(mode);
    exe.install();

    vulkan_exe.setBuildMode(mode);
    vulkan_exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const vulkan_run_cmd = exe.run();
    vulkan_run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const vulkan_run_step = b.step("run-vulkan", "Run the app");
    vulkan_run_step.dependOn(&vulkan_run_cmd.step);
}
