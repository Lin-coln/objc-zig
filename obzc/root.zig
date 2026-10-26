const core = @import("src/root.zig");

pub const ffi = @import("ffi/root.zig");
pub const c = ffi.c;
pub const utils = core.utils;
pub const rt = core.rt;
pub const Block = core.Block;
pub const AutoReleasePool = core.AutoReleasePool;
pub const helpers = @import("helpers/root.zig");

test {
    _ = core;
    _ = helpers;
}
