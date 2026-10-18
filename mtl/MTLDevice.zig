const std = @import("std");
const objc = @import("objc");
const ns = @import("objc/ns");
const macos = @import("macos");
const mtl = @import("macos/mtl-abi");
const MTLCommandQueue = @import("MTLCommandQueue.zig").MTLCommandQueue;
const MTLTextureDescriptor = @import("MTLTextureDescriptor.zig").MTLTextureDescriptor;
const MTLTexture = @import("MTLTexture.zig").MTLTexture;
const MTLCompileOptions = @import("MTLCompileOptions.zig").MTLCompileOptions;
const MTLLibrary = @import("MTLLibrary.zig").MTLLibrary;
const MTLRenderPipelineDescriptor = @import("MTLRenderPipelineDescriptor.zig").MTLRenderPipelineDescriptor;
const MTLRenderPipelineState = @import("MTLRenderPipelineState.zig").MTLRenderPipelineState;

pub const MTLDevice = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    /// Returns an owned default device, or null if Metal is unavailable.
    pub fn createSystemDefaultDevice() ?*Self {
        return @ptrCast(mtl.MTLCreateSystemDefaultDevice());
    }

    pub const newCommandQueue = h.method("newCommandQueue", fn () ?*MTLCommandQueue);
    pub const newTexture = h.method("newTextureWithDescriptor:", fn (*MTLTextureDescriptor) ?*MTLTexture);
    pub const newTextureWithIOSurface = h.method("newTextureWithDescriptor:iosurface:plane:", fn (*MTLTextureDescriptor, macos.IOSurfaceRef, usize) ?*MTLTexture);
    pub const newLibrary = h.method("newLibraryWithSource:options:error:", fn (*ns.NSString, ?*MTLCompileOptions, ?*?*ns.NSError) ?*MTLLibrary);
    pub const newRenderPipelineState = h.method("newRenderPipelineStateWithDescriptor:error:", fn (*MTLRenderPipelineDescriptor, ?*?*ns.NSError) ?*MTLRenderPipelineState);
};

test "MTLDevice: failed shader compilation reports NSError" {
    const pool = objc.AutoReleasePool.create();
    defer pool.release();
    const device = MTLDevice.createSystemDefaultDevice() orelse return error.SkipZigTest;
    defer device.release();
    const source = ns.NSString.init("this is not a Metal shader").?;
    defer source.release();
    var compile_error: ?*ns.NSError = null;
    try std.testing.expect(device.newLibrary(source, null, &compile_error) == null);
    try std.testing.expect(compile_error != null);
    try std.testing.expect(compile_error.?.domain().length() != 0);
}
