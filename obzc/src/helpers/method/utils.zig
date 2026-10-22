pub fn resolveReceiverType(comptime T: type, comptime call: anytype) ?type {
    const info_call = switch (@typeInfo(@TypeOf(call))) {
        .@"fn" => |info| info,
        else => @compileError("call should be a fn"),
    };

    const Receiver: ?type = blk: {
        if (info_call.param_types.len < 1) break :blk null;
        const Arg0 = info_call.param_types[0] orelse break :blk null;
        const matches = switch (@typeInfo(Arg0)) {
            // *T or *const T
            .pointer => |ptr| ptr.size == .one and ptr.child == T,
            // T
            else => Arg0 == T,
        };
        break :blk if (matches) Arg0 else null;
    };

    return Receiver;
}
