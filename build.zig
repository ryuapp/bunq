const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // QuickJS source files
    const quickjs_sources = [_][]const u8{
        "quickjs/cutils.c",
        "quickjs/libregexp.c",
        "quickjs/libunicode.c",
        "quickjs/dtoa.c",
        "quickjs/quickjs.c",
        "quickjs/quickjs-libc.c",
    };

    // C compilation flags - optimized for minimal binary size
    const c_flags = &[_][]const u8{
        "-std=c11",
        "-D_GNU_SOURCE",
        "-Os", // Optimize for size
        "-ffunction-sections", // Enable function sections for linker GC
        "-fdata-sections", // Enable data sections for linker GC
        "-flto", // Link Time Optimization
    };

    // QuickJS static library
    const qjs_lib = b.addLibrary(.{
        .name = "qjs",
        .root_module = b.createModule(.{
            .root_source_file = null,
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    qjs_lib.root_module.addIncludePath(b.path("quickjs"));
    qjs_lib.root_module.addCSourceFiles(.{
        .files = &quickjs_sources,
        .flags = c_flags,
    });

    // Link pthread on Linux
    if (target.result.os.tag == .linux) {
        qjs_lib.linkSystemLibrary("pthread");
    }

    const zjs_lib = b.addLibrary(.{
        .name = "zjs",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    zjs_lib.root_module.addIncludePath(b.path("src"));
    zjs_lib.root_module.addIncludePath(b.path("quickjs"));

    zjs_lib.root_module.linkLibrary(qjs_lib);

    const exe = b.addExecutable(.{
        .name = "bunq",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/demo.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    exe.root_module.addIncludePath(b.path("src"));
    exe.root_module.addIncludePath(b.path("quickjs"));
    exe.root_module.linkLibrary(zjs_lib);

    // Install steps
    b.installArtifact(zjs_lib);
    b.installArtifact(exe);

    // Install header files
    b.installFile("quickjs/quickjs.h", "include/quickjs.h");
    b.installFile("quickjs/quickjs-libc.h", "include/quickjs-libc.h");

    // Create a run step for the demo
    const run_cmd = b.addRunArtifact(exe);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the demo application");
    run_step.dependOn(&run_cmd.step);
}
