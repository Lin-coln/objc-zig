// basic
pub const rt = @import("rt/root.zig");
pub const Block = @import("Block/Self.zig").Block;

pub const AutoReleasePool = @import("AutoReleasePool.zig").AutoReleasePool;

test {
    _ = @import("rt/root.zig");
    _ = @import("Block/Self.zig");
    _ = @import("AutoReleasePool.zig");
}
