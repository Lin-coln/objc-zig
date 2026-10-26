pub const resolveTypeName = @import("resolveTypeName.zig").resolveTypeName;

pub const toSpreadedFn = @import("spread.zig").toSpreadedFn;

test {
    _ = @import("resolveTypeName.zig");
    _ = @import("spread.zig");
}
