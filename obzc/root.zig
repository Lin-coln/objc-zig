pub const ffi = @import("ffi/root.zig");
pub const c = ffi.c;
pub const cast = ffi.cast;
pub const AutoReleasePool = ffi.AutoReleasePool;

pub const encode = @import("encode/root.zig").encode;

pub const Block = @import("block/root.zig").Block;

pub const helpers = @import("helpers/root.zig");

pub fn h(comptime T: type) type {
    return struct {
        pub const f = helpers.ClassFactory(T);
        pub const cls = helpers.Class(T);
        pub const obj = helpers.Object(T);

        pub const retain = obj.retain;
        pub const release = obj.release;
        pub const call = obj.call;
        pub const prop = obj.prop;
        pub const method = obj.method;
        pub const ivar = obj.ivar;
    };
}

test {
    _ = @import("utils/root.zig");
    _ = ffi;
    _ = @import("encode/root.zig");
    _ = @import("block/root.zig");
    _ = helpers;
}
