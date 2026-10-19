const std = @import("std");
const obzc = @import("obzc");
const ns = @import("obzc-ns");
const MTLFunction = @import("MTLFunction.zig").MTLFunction;

pub const MTLLibrary = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Returns an owned function, or null when the name is absent.
    pub const newFunction = h.method("newFunctionWithName:", fn (*ns.NSString) ?*MTLFunction);
};

test "MTLLibrary: newFunction finds a named function and returns null for a missing name" {
    const MTLDevice = @import("MTLDevice.zig").MTLDevice;
    const pool = obzc.AutoReleasePool.create();
    defer pool.release();
    const device = MTLDevice.createSystemDefaultDevice() orelse return error.SkipZigTest;
    defer device.release();
    const source = ns.NSString.init("kernel void available() {}").?;
    defer source.release();
    var compile_error: ?*ns.NSError = null;
    const library = device.newLibrary(source, null, &compile_error) orelse {
        if (compile_error) |err| err.log();
        return error.ShaderCompilationFailed;
    };
    defer library.release();

    const name = ns.NSString.init("available").?;
    defer name.release();
    const function = library.newFunction(name).?;
    defer function.release();
    const missing = ns.NSString.init("missing_function").?;
    defer missing.release();
    try std.testing.expect(library.newFunction(missing) == null);
}
