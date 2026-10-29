const std = @import("std");
pub const resolveTypeName = @import("resolveTypeName.zig").resolveTypeName;
pub const resolveFnInfo = @import("resolveFnInfo.zig").resolveFnInfo;
pub const resolveReceiverType = @import("resolveReceiverType.zig").resolveReceiverType;

pub const toSpreadedFn = @import("spread.zig").toSpreadedFn;

test {
    std.testing.refAllDecls(@This());
}
