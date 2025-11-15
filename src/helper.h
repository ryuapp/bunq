#include <quickjs.h>

static inline JSValue js_undefined_value(void) { return JS_UNDEFINED; }
static inline JSValue js_true_value(void) { return JS_TRUE; }
static inline JSValue js_false_value(void) { return JS_FALSE; }

// Helper to create a resolved promise
static inline JSValue js_resolved_promise(JSContext *ctx, JSValue value) {
    JSValue resolving_funcs[2];
    JSValue promise = JS_NewPromiseCapability(ctx, resolving_funcs);
    if (JS_IsException(promise)) {
        JS_FreeValue(ctx, value);
        return promise;
    }
    JSValue ret = JS_Call(ctx, resolving_funcs[0], JS_UNDEFINED, 1, &value);
    JS_FreeValue(ctx, resolving_funcs[0]);
    JS_FreeValue(ctx, resolving_funcs[1]);
    JS_FreeValue(ctx, value);
    JS_FreeValue(ctx, ret);
    return promise;
}

// Helper to create a rejected promise
static inline JSValue js_rejected_promise(JSContext *ctx, JSValue error) {
    JSValue resolving_funcs[2];
    JSValue promise = JS_NewPromiseCapability(ctx, resolving_funcs);
    if (JS_IsException(promise)) {
        JS_FreeValue(ctx, error);
        return promise;
    }
    JSValue ret = JS_Call(ctx, resolving_funcs[1], JS_UNDEFINED, 1, &error);
    JS_FreeValue(ctx, resolving_funcs[0]);
    JS_FreeValue(ctx, resolving_funcs[1]);
    JS_FreeValue(ctx, error);
    JS_FreeValue(ctx, ret);
    return promise;
}
