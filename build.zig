const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("model-viewer", "src/main.zig");
    const vulkan_exe = b.addExecutable("model-viewer-vulkan", "src/main_vulkan.zig");

    exe.addPackagePath("xq3d", "./dependencies/zig-gamedev-lib/src/lib.zig");
    vulkan_exe.addPackagePath("xq3d", "./dependencies/zig-gamedev-lib/src/lib.zig");

    exe.addCSourceFile("dependencies/glad/src/glad.c", &[_][]const u8{"-std=c99"});
    exe.addCSourceFile("dependencies/stb/stb_image_impl.c", &[_][]const u8{"-std=c99"});
    exe.addIncludeDir("dependencies/glad/include");
    exe.addIncludeDir("dependencies/glfw/include");
    exe.addIncludeDir("dependencies/stb");

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

    var image_tests = b.addTest("src/image.zig");
    image_tests.addCSourceFile("dependencies/stb/stb_image_impl.c", &[_][]const u8{"-std=c99"});
    image_tests.setBuildMode(mode);
    image_tests.addIncludeDir("dependencies/stb");
    image_tests.linkLibC();

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&image_tests.step);

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const vulkan_run_cmd = vulkan_exe.run();
    vulkan_run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const vulkan_run_step = b.step("run-vulkan", "Run the app");
    vulkan_run_step.dependOn(&vulkan_run_cmd.step);
}
