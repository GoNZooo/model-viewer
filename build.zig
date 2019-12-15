const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("model-viewer", "src/main.zig");

    exe.addCSourceFile("dependencies/glad/src/glad.c", &[_][]const u8{"-std=c99"});
    exe.addIncludeDir("dependencies/glad/include");
    exe.addIncludeDir("dependencies/glfw/include");

    exe.addLibPath("dependencies/glfw");

    exe.linkLibC();
    exe.linkSystemLibrary("opengl32");
    exe.linkSystemLibrary("glfw3");
    exe.linkSystemLibrary("shell32");
    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("gdi32");

    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
