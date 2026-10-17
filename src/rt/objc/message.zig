const builtin = @import("builtin");
const c = @import("../../c.zig").c;
const Class = @import("../Class.zig").Class;
const Object = @import("../Object.zig").Object;
const Sel = @import("../Sel.zig").Sel;

/// Sends `sel` to `target` by calling objc_msgSend cast to `fn (@TypeOf(target), SEL, args...) Return`.
/// `Return` and the types of `args` must match the method's declaration exactly; mismatches are not caught at compile time.
pub fn msgSend(target: anytype, comptime Return: type, sel: *Sel, args: anytype) Return {
    // See objc/message.h: x86_64 needs objc_msgSend_stret for structs returned in memory
    // and objc_msgSend_fpret for long double; arm64 uses objc_msgSend for everything.
    const send = comptime switch (builtin.target.cpu.arch) {
        .aarch64 => &c.objc_msgSend,
        .x86_64 => if (@typeInfo(Return) == .@"struct" and @sizeOf(Return) > 16)
            &c.objc_msgSend_stret
        else if (Return == c_longdouble)
            &c.objc_msgSend_fpret
        else
            &c.objc_msgSend,
        else => @compileError("unsupported architecture for objc_msgSend"),
    };
    const f: *const MsgSendFn(@TypeOf(target), Return, @TypeOf(args)) = @ptrCast(send);
    return @call(.auto, f, .{ target, sel } ++ args);
}

/// Like `msgSend`, but starts the method lookup at `superclass` instead of `target`'s class.
pub fn msgSendSuper(target: anytype, superclass: *Class, comptime Return: type, sel: *Sel, args: anytype) Return {
    // There is no objc_msgSendSuper_fpret: the receiver of a super send is never nil.
    const send = comptime switch (builtin.target.cpu.arch) {
        .aarch64 => &c.objc_msgSendSuper,
        .x86_64 => if (@typeInfo(Return) == .@"struct" and @sizeOf(Return) > 16)
            &c.objc_msgSendSuper_stret
        else
            &c.objc_msgSendSuper,
        else => @compileError("unsupported architecture for objc_msgSendSuper"),
    };
    var super: c.struct_objc_super = .{ .receiver = @ptrCast(target), .super_class = @ptrCast(superclass) };
    const f: *const MsgSendFn(*c.struct_objc_super, Return, @TypeOf(args)) = @ptrCast(send);
    return @call(.auto, f, .{ &super, sel } ++ args);
}

fn MsgSendFn(comptime Target: type, comptime Return: type, comptime Args: type) type {
    const field_types = @typeInfo(Args).@"struct".field_types;
    var param_types: [field_types.len + 2]type = undefined;
    param_types[0] = Target;
    param_types[1] = *Sel;
    for (field_types, 0..) |T, i| param_types[i + 2] = T;
    return @Fn(&param_types, &@splat(.{}), Return, .{ .@"callconv" = .c });
}
