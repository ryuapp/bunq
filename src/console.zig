const std = @import("std");
const c = @cImport({
    @cInclude("quickjs.h");
    @cInclude("quickjs-libc.h");
    @cInclude("helper.h");
});

/// C binding for console.log
fn console_log(ctx: ?*c.JSContext, this_val: c.JSValue, argc: c_int, argv: [*c]c.JSValue) callconv(.c) c.JSValue {
    _ = this_val;
    const ctx_nn = ctx orelse return c.js_undefined_value();

    for (0..@as(usize, @intCast(argc))) |i| {
        const str_ptr = c.JS_ToCString(ctx_nn, argv[i]);
        if (str_ptr) |ptr| {
            std.debug.print("{s}", .{std.mem.span(ptr)});
            c.JS_FreeCString(ctx_nn, ptr);
        } else {
            const str_val = c.JS_ToString(ctx_nn, argv[i]);
            defer c.JS_FreeValue(ctx_nn, str_val);

            if (c.JS_ToCString(ctx_nn, str_val)) |ptr| {
                std.debug.print("{s}", .{std.mem.span(ptr)});
                c.JS_FreeCString(ctx_nn, ptr);
            }
        }

        if (i < @as(usize, @intCast(argc)) - 1) {
            std.debug.print(" ", .{});
        }
    }

    std.debug.print("\n", .{});
    return c.js_undefined_value();
}

/// C binding for console.error
fn console_error(ctx: ?*c.JSContext, this_val: c.JSValue, argc: c_int, argv: [*c]c.JSValue) callconv(.c) c.JSValue {
    _ = this_val;
    const ctx_nn = ctx orelse return c.js_undefined_value();

    for (0..@as(usize, @intCast(argc))) |i| {
        const str_ptr = c.JS_ToCString(ctx_nn, argv[i]);
        if (str_ptr) |ptr| {
            std.debug.print("{s}", .{std.mem.span(ptr)});
            c.JS_FreeCString(ctx_nn, ptr);
        } else {
            const str_val = c.JS_ToString(ctx_nn, argv[i]);
            defer c.JS_FreeValue(ctx_nn, str_val);

            if (c.JS_ToCString(ctx_nn, str_val)) |ptr| {
                std.debug.print("{s}", .{std.mem.span(ptr)});
                c.JS_FreeCString(ctx_nn, ptr);
            }
        }

        if (i < @as(usize, @intCast(argc)) - 1) {
            std.debug.print(" ", .{});
        }
    }

    std.debug.print("\n", .{});
    return c.js_undefined_value();
}

/// Setup console object and add it to the global object
/// Accepts any type with ctx and global fields (compatible with JS_App)
pub fn setup(app: anytype) void {
    // Type-cast the context pointer to work across module boundaries
    const ctx: ?*c.JSContext = @ptrCast(app.ctx);
    const ctx_nn = ctx orelse return;

    // Use the global already obtained in main.zig
    const global = @as(c.JSValue, @bitCast(app.global));

    const console_obj = c.JS_NewObject(ctx_nn);
    defer c.JS_FreeValue(ctx_nn, console_obj);

    // Add console.log function
    const log_func = c.JS_NewCFunction(ctx_nn, console_log, "log", -1);
    _ = c.JS_SetPropertyStr(ctx_nn, console_obj, "log", log_func);

    // Add console.error function
    const error_func = c.JS_NewCFunction(ctx_nn, console_error, "error", -1);
    _ = c.JS_SetPropertyStr(ctx_nn, console_obj, "error", error_func);

    // Add console to global object
    _ = c.JS_SetPropertyStr(ctx_nn, global, "console", c.JS_DupValue(ctx_nn, console_obj));
}
