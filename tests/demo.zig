const std = @import("std");
const c = @cImport({
    @cInclude("quickjs.h");
});

// JS_App struct definition
const JS_App = extern struct {
    rt: *c.JSRuntime,
    ctx: ?*c.JSContext,
    global: c.JSValue,
};

// C function declarations from main.zig
extern fn js_app_new(max_stack_size: c_int, max_heap_size: c_int) callconv(.c) ?*JS_App;
extern fn js_app_free(app: ?*JS_App) callconv(.c) void;
extern fn js_app_eval(app: ?*JS_App, data: [*]const u8, data_len: c_int, name: [*:0]const u8, is_module: c_int) callconv(.c) c_int;
extern fn js_app_eval_file(app: ?*JS_App, filename: [*:0]const u8) callconv(.c) c_int;
extern fn js_app_run_loop(app: ?*JS_App) callconv(.c) void;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Create JavaScript runtime
    const app = js_app_new(-1, -1);
    if (app == null) {
        std.debug.print("Failed to create JS app\n", .{});
        return;
    }
    defer js_app_free(app);

    // If a file is provided as argument, evaluate it
    if (args.len > 1) {
        const filename = args[1];
        const ret = js_app_eval_file(app, filename.ptr);
        if (ret != 0) {
            std.debug.print("Error evaluating file: {s}\n", .{filename});
            return;
        }
        // Run event loop to handle promises/async operations
        js_app_run_loop(app);
    } else {
        // Test 0: console.log test
        std.debug.print("=== Test 0: console.log ===\n", .{});
        const code0 =
            \\console.log("Hello from console.log!");
            \\console.log("Number:", 42);
            \\console.log("Array:", [1, 2, 3]);
            \\console.log("String:", "Hello", "World");
        ;
        var ret = js_app_eval(app, code0.ptr, code0.len, "test0", 0);
        if (ret != 0) {
            std.debug.print("Error in test 0\n", .{});
            return;
        }
        std.debug.print("✓ Test 0 passed\n\n", .{});

        // Test 1: Simple arithmetic
        std.debug.print("=== Test 1: Simple arithmetic ===\n", .{});
        const code1 = "console.log(\"1 + 2 =\", 1 + 2);";
        ret = js_app_eval(app, code1.ptr, code1.len, "test1", 0);
        if (ret != 0) {
            std.debug.print("Error in test 1\n", .{});
            return;
        }
        std.debug.print("✓ Test 1 passed\n\n", .{});

        // Test 2: Bun.file write and read
        std.debug.print("=== Test 2: Bun.file write and read ===\n", .{});
        const code2 =
            \\const file = Bun.file("zig-out/bun_test.txt");
            \\file.write("Hello from Bun.file!");
            \\const content = file.text();
            \\console.log("Read:", content);
        ;
        ret = js_app_eval(app, code2.ptr, code2.len, "test2", 0);
        if (ret != 0) {
            std.debug.print("Error in test 2\n", .{});
            return;
        }
        std.debug.print("✓ Test 2 passed\n\n", .{});

        // Test 3: Bun.file exists
        std.debug.print("=== Test 3: Bun.file exists ===\n", .{});
        const code3 =
            \\const file2 = Bun.file("zig-out/bun_test.txt");
            \\const exists = file2.exists();
            \\console.log("File exists:", exists);
        ;
        ret = js_app_eval(app, code3.ptr, code3.len, "test3", 0);
        if (ret != 0) {
            std.debug.print("Error in test 3\n", .{});
            return;
        }
        std.debug.print("✓ Test 3 passed\n\n", .{});
    }

    std.debug.print("=== All tests completed successfully ===\n", .{});
}
