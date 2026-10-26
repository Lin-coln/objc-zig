pub const resolveTypeName = @import("resolveTypeName.zig").resolveTypeName;
pub const resolveFnInfo = @import("resolveFnInfo.zig").resolveFnInfo;
pub const resolveReceiverType = @import("resolveReceiverType.zig").resolveReceiverType;

pub const toSpreadedFn = @import("spread.zig").toSpreadedFn;

test {
    _ = @import("resolveTypeName.zig");
    _ = @import("resolveFnInfo.zig");
    _ = @import("resolveReceiverType.zig");
    _ = @import("spread.zig");
}
