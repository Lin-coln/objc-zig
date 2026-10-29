const std = @import("std");
const core = @import("core");
const Metadata = core.Metadata;
const mtl = @import("mtl-abi");

pub const MTLFunction = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const functionType = h.method("functionType", fn () mtl.MTLFunctionType);
};

test "MTLFunction: functionType identifies a compute function" {
    const ns = @import("obzc-ns");
    const MTLDevice = @import("MTLDevice.zig").MTLDevice;
    const pool = core.AutoReleasePool.create();
    defer pool.release();
    const device = MTLDevice.createSystemDefaultDevice() orelse return error.SkipZigTest;
    defer device.release();
    const source = ns.NSString.init("kernel void compute() {}").?;
    defer source.release();
    const library = try device.newLibrary(source, null);
    defer library.release();
    const name = ns.NSString.init("compute").?;
    defer name.release();
    const function = library.newFunction(name).?;
    defer function.release();

    try std.testing.expectEqual(@as(mtl.MTLFunctionType, mtl.MTLFunctionTypeKernel), function.functionType());
}
