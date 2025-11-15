const std = @import("std");
const c = @cImport({
    @cInclude("quickjs.h");
    @cInclude("quickjs-libc.h");
    @cInclude("helper.h");
});

// BunFile object to hold file path and operations
pub const BunFile = struct {
    path: []const u8,

    pub fn text(self: BunFile, allocator: std.mem.Allocator) ![]const u8 {
        var file = try std.fs.cwd().openFile(self.path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const buffer = try allocator.alloc(u8, file_size);
        errdefer allocator.free(buffer);

        const bytes_read = try file.readAll(buffer);
        if (bytes_read != file_size) {
            return error.UnexpectedEndOfFile;
        }

        return buffer;
    }

    pub fn write(self: BunFile, data: []const u8) !void {
        var file = try std.fs.cwd().createFile(self.path, .{});
        defer file.close();
        try file.writeAll(data);
    }

    pub fn exists(self: BunFile) !bool {
        var file = std.fs.cwd().openFile(self.path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                return false;
            }
            return err;
        };
        file.close();
        return true;
    }

    pub fn delete(self: BunFile) !void {
        try std.fs.cwd().deleteFile(self.path);
    }
};

// Global allocator (shared with main.zig)
var gpa: ?*std.heap.GeneralPurposeAllocator(.{}) = null;

// C binding for Bun.file
fn bun_file(ctx: ?*c.JSContext, this_val: c.JSValue, argc: c_int, argv: [*c]c.JSValue) callconv(.c) c.JSValue {
    _ = this_val;
    const ctx_nn = ctx orelse return c.js_undefined_value();

    if (argc < 1) {
        return c.js_undefined_value();
    }

    // Get path argument as string
    const path_ptr = c.JS_ToCString(ctx_nn, argv[0]);
    if (path_ptr == null) {
        return c.js_undefined_value();
    }
    defer c.JS_FreeCString(ctx_nn, path_ptr);

    const path = std.mem.span(path_ptr.?);

    // Create a new object to represent the BunFile
    const file_obj = c.JS_NewObject(ctx_nn);

    // Store the path as a property
    const path_str = c.JS_NewStringLen(ctx_nn, path.ptr, path.len);
    _ = c.JS_SetPropertyStr(ctx_nn, file_obj, "__path__", path_str);

    // Add text() method
    const text_func = c.JS_NewCFunction(ctx_nn, bunfile_text, "text", 0);
    _ = c.JS_SetPropertyStr(ctx_nn, file_obj, "text", text_func);

    // Add write() method
    const write_func = c.JS_NewCFunction(ctx_nn, bunfile_write, "write", 1);
    _ = c.JS_SetPropertyStr(ctx_nn, file_obj, "write", write_func);

    // Add exists() method
    const exists_func = c.JS_NewCFunction(ctx_nn, bunfile_exists, "exists", 0);
    _ = c.JS_SetPropertyStr(ctx_nn, file_obj, "exists", exists_func);

    // Add delete() method
    const delete_func = c.JS_NewCFunction(ctx_nn, bunfile_delete, "delete", 0);
    _ = c.JS_SetPropertyStr(ctx_nn, file_obj, "delete", delete_func);

    return file_obj;
}

/// BunFile.text() - read file as string
fn bunfile_text(ctx: ?*c.JSContext, this_val: c.JSValue, argc: c_int, argv: [*c]c.JSValue) callconv(.c) c.JSValue {
    _ = argc;
    _ = argv;
    const ctx_nn = ctx orelse return c.js_undefined_value();

    // Get __path__ from this_val
    const path_val = c.JS_GetPropertyStr(ctx_nn, this_val, "__path__");
    defer c.JS_FreeValue(ctx_nn, path_val);

    const path_ptr = c.JS_ToCString(ctx_nn, path_val);
    if (path_ptr == null) {
        return c.js_undefined_value();
    }
    defer c.JS_FreeCString(ctx_nn, path_ptr);

    const path = std.mem.span(path_ptr.?);

    // Create a BunFile and read
    const file_obj = BunFile{ .path = path };
    const content = file_obj.text(gpa.?.allocator()) catch |err| {
        std.debug.print("Error reading file {s}: {}\n", .{ path, err });
        const error_str = c.JS_NewString(ctx_nn, "Failed to read file");
        return c.js_rejected_promise(ctx_nn, error_str);
    };
    defer gpa.?.allocator().free(content);

    // Create JSValue string and wrap in resolved promise
    const str_val = c.JS_NewStringLen(ctx_nn, content.ptr, content.len);
    return c.js_resolved_promise(ctx_nn, str_val);
}

/// BunFile.write(data) - write data to file
fn bunfile_write(ctx: ?*c.JSContext, this_val: c.JSValue, argc: c_int, argv: [*c]c.JSValue) callconv(.c) c.JSValue {
    const ctx_nn = ctx orelse return c.js_undefined_value();

    if (argc < 1) {
        return c.js_undefined_value();
    }

    // Get __path__ from this_val
    const path_val = c.JS_GetPropertyStr(ctx_nn, this_val, "__path__");
    defer c.JS_FreeValue(ctx_nn, path_val);

    const path_ptr = c.JS_ToCString(ctx_nn, path_val);
    if (path_ptr == null) {
        return c.js_undefined_value();
    }
    defer c.JS_FreeCString(ctx_nn, path_ptr);

    // Get data argument
    const data_ptr = c.JS_ToCString(ctx_nn, argv[0]);
    if (data_ptr == null) {
        return c.js_undefined_value();
    }
    defer c.JS_FreeCString(ctx_nn, data_ptr);

    const path = std.mem.span(path_ptr.?);
    const data = std.mem.span(data_ptr.?);

    // Create a BunFile and write
    const file_obj = BunFile{ .path = path };
    file_obj.write(data) catch |err| {
        std.debug.print("Error writing file {s}: {}\n", .{ path, err });
        const error_str = c.JS_NewString(ctx_nn, "Failed to write file");
        return c.js_rejected_promise(ctx_nn, error_str);
    };

    // Return resolved promise with undefined
    return c.js_resolved_promise(ctx_nn, c.js_undefined_value());
}

/// BunFile.exists() - check if file exists
fn bunfile_exists(ctx: ?*c.JSContext, this_val: c.JSValue, argc: c_int, argv: [*c]c.JSValue) callconv(.c) c.JSValue {
    _ = argc;
    _ = argv;
    const ctx_nn = ctx orelse return c.js_undefined_value();

    // Get __path__ from this_val
    const path_val = c.JS_GetPropertyStr(ctx_nn, this_val, "__path__");
    defer c.JS_FreeValue(ctx_nn, path_val);

    const path_ptr = c.JS_ToCString(ctx_nn, path_val);
    if (path_ptr == null) {
        return c.js_undefined_value();
    }
    defer c.JS_FreeCString(ctx_nn, path_ptr);

    const path = std.mem.span(path_ptr.?);

    // Create a BunFile and check
    const file_obj = BunFile{ .path = path };
    const file_exists = file_obj.exists() catch {
        return c.js_resolved_promise(ctx_nn, c.js_false_value());
    };

    const result = if (file_exists) c.js_true_value() else c.js_false_value();
    return c.js_resolved_promise(ctx_nn, result);
}

/// BunFile.delete() - delete file
fn bunfile_delete(ctx: ?*c.JSContext, this_val: c.JSValue, argc: c_int, argv: [*c]c.JSValue) callconv(.c) c.JSValue {
    _ = argc;
    _ = argv;
    const ctx_nn = ctx orelse return c.js_undefined_value();

    // Get __path__ from this_val
    const path_val = c.JS_GetPropertyStr(ctx_nn, this_val, "__path__");
    defer c.JS_FreeValue(ctx_nn, path_val);

    const path_ptr = c.JS_ToCString(ctx_nn, path_val);
    if (path_ptr == null) {
        return c.js_undefined_value();
    }
    defer c.JS_FreeCString(ctx_nn, path_ptr);

    const path = std.mem.span(path_ptr.?);

    // Create a BunFile and delete
    const file_obj = BunFile{ .path = path };
    file_obj.delete() catch |err| {
        std.debug.print("Error deleting file {s}: {}\n", .{ path, err });
        const error_str = c.JS_NewString(ctx_nn, "Failed to delete file");
        return c.js_rejected_promise(ctx_nn, error_str);
    };

    // Return resolved promise with undefined
    return c.js_resolved_promise(ctx_nn, c.js_undefined_value());
}

/// Setup Bun object and add it to the global object
pub fn setup(app: anytype, allocator_ptr: *std.heap.GeneralPurposeAllocator(.{})) void {
    // Store allocator
    gpa = allocator_ptr;

    // Type-cast the context pointer to work across module boundaries
    const ctx: ?*c.JSContext = @ptrCast(app.ctx);
    const ctx_nn = ctx orelse return;

    // Use the global already obtained in main.zig
    const global = @as(c.JSValue, @bitCast(app.global));

    const bun_obj = c.JS_NewObject(ctx_nn);
    defer c.JS_FreeValue(ctx_nn, bun_obj);

    // Add Bun.file function
    const file_func = c.JS_NewCFunction(ctx_nn, bun_file, "file", 1);
    _ = c.JS_SetPropertyStr(ctx_nn, bun_obj, "file", file_func);

    // Add Bun to global object
    _ = c.JS_SetPropertyStr(ctx_nn, global, "Bun", c.JS_DupValue(ctx_nn, bun_obj));
}
