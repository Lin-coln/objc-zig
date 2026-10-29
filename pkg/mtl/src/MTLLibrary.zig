const std = @import("std");
const core = @import("core");
const Metadata = core.Metadata;
const ns = @import("obzc-ns");
const MTLFunction = @import("MTLFunction.zig").MTLFunction;

pub const MTLLibrary = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Returns an owned function, or null when the name is absent.
    pub const newFunction = h.method("newFunctionWithName:", fn (*ns.NSString) ?*MTLFunction);
};

test "MTLLibrary: newFunction finds a named function and returns null for a missing name" {
    const MTLDevice = @import("MTLDevice.zig").MTLDevice;
    const pool = core.AutoReleasePool.create();
    defer pool.release();
    const device = MTLDevice.createSystemDefaultDevice() orelse return error.SkipZigTest;
    defer device.release();
    const source = ns.NSString.init("kernel void available() {}").?;
    defer source.release();
    const library = try device.newLibrary(source, null);
    defer library.release();

    const name = ns.NSString.init("available").?;
    defer name.release();
    const function = library.newFunction(name).?;
    defer function.release();
    const missing = ns.NSString.init("missing_function").?;
    defer missing.release();
    try std.testing.expect(library.newFunction(missing) == null);
}
