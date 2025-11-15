const std = @import("std");
const c = @cImport({
    @cInclude("quickjs.h");
    @cInclude("quickjs-libc.h");
    @cInclude("helper.h");
});

// JS_App struct definition
pub const JS_App = extern struct {
    rt: *c.JSRuntime,
    ctx: ?*c.JSContext,
    global: c.JSValue,
};

const console_mod = @import("console.zig");
const bun = @import("bun.zig");

// Global allocator
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var wrapper_initialized = false;

/// Create and initialize a new JS application context
pub export fn js_app_new(max_stack_size: c_int, max_heap_size: c_int) callconv(.c) ?*JS_App {
    const app = std.c.malloc(@sizeOf(JS_App)) orelse return null;
    const app_typed = @as(*JS_App, @ptrCast(@alignCast(app)));

    // Initialize Zig wrapper
    if (!wrapper_initialized) {
        wrapper_initialized = true;
    }

    // Create runtime with optional size limits
    app_typed.rt = c.JS_NewRuntime() orelse {
        std.c.free(app);
        return null;
    };
    errdefer c.JS_FreeRuntime(app_typed.rt);

    if (max_heap_size > 0) {
        c.JS_SetMemoryLimit(app_typed.rt, @as(usize, @intCast(max_heap_size)));
    }

    if (max_stack_size > 0) {
        c.JS_SetMaxStackSize(app_typed.rt, @as(usize, @intCast(max_stack_size)));
    }

    // Create context
    app_typed.ctx = c.JS_NewContext(app_typed.rt) orelse {
        c.JS_FreeRuntime(app_typed.rt);
        std.c.free(app);
        return null;
    };
    errdefer c.JS_FreeContext(app_typed.ctx);

    // Get global object
    app_typed.global = c.JS_GetGlobalObject(app_typed.ctx);

    // Setup console object
    console_mod.setup(app_typed);

    // Setup Bun object
    bun.setup(app_typed, &gpa);

    return app_typed;
}

/// Free JS application context and all associated resources
pub export fn js_app_free(app: ?*JS_App) callconv(.c) void {
    if (app == null) return;
    const app_typed = app.?;

    c.JS_FreeValue(app_typed.ctx, app_typed.global);
    c.JS_FreeContext(app_typed.ctx);
    c.JS_FreeRuntime(app_typed.rt);
    std.c.free(app_typed);
}

/// Helper function to evaluate a buffer
fn eval_buf(ctx: *c.JSContext, buf: [*]const u8, buf_len: c_int, filename: [*:0]const u8, eval_flags: c_int) callconv(.c) c_int {
    const val = c.JS_Eval(ctx, buf, @as(usize, @intCast(buf_len)), filename, eval_flags);
    defer c.JS_FreeValue(ctx, val);

    if (c.JS_IsException(val)) {
        c.js_std_dump_error(ctx);
        return -1;
    }
    return 0;
}

/// Evaluate JavaScript code from a buffer
pub export fn js_app_eval(app: ?*JS_App, data: [*]const u8, data_len: c_int, name: [*:0]const u8, is_module: c_int) callconv(.c) c_int {
    const app_typed = app orelse return -1;
    const ctx_nn = app_typed.ctx orelse return -1;

    const flags: c_int = if (is_module != 0) c.JS_EVAL_TYPE_MODULE else c.JS_EVAL_TYPE_GLOBAL;

    return eval_buf(ctx_nn, data, data_len, name, flags);
}

/// Evaluate JavaScript code from a file
pub export fn js_app_eval_file(app: ?*JS_App, filename: [*:0]const u8) callconv(.c) c_int {
    if (app == null) return -1;
    const app_typed = app.?;

    const f = c.fopen(filename, "rb") orelse {
        std.debug.print("Error opening file: {s}\n", .{filename});
        return -1;
    };
    defer _ = c.fclose(f);

    // Evaluate as module to support top-level await
    const is_module: c_int = 1;

    // Read file contents
    _ = c.fseek(f, 0, 2);
    const size = c.ftell(f);
    _ = c.fseek(f, 0, 0);

    if (size < 0) return -1;

    const buf = std.c.malloc(@as(usize, @intCast(size))) orelse return -1;
    defer std.c.free(buf);

    const bytes_read = c.fread(buf, 1, @as(usize, @intCast(size)), f);
    if (bytes_read != @as(usize, @intCast(size))) {
        return -1;
    }

    const ctx_nn = app_typed.ctx orelse return -1;
    const flags: c_int = if (is_module != 0) c.JS_EVAL_TYPE_MODULE else c.JS_EVAL_TYPE_GLOBAL;
    return eval_buf(ctx_nn, @as([*]const u8, @ptrCast(buf)), @as(c_int, @intCast(size)), filename, flags);
}

/// Run the event loop
pub export fn js_app_run_loop(app: ?*JS_App) callconv(.c) void {
    const app_typed = app orelse return;
    const ctx_nn = app_typed.ctx orelse return;

    _ = c.js_std_loop(ctx_nn);
}
