const ffi = @import("../ffi/root.zig");

/// Calls a method, converting top-level bool arguments and returns through BOOL.
pub fn call(receiver: anytype, comptime Return: type, name: [:0]const u8, args: anytype) Return {
    const fields = @typeInfo(@TypeOf(args)).@"struct".field_types;
    comptime var types: [fields.len]type = undefined;
    inline for (fields, 0..) |Field, i| types[i] = ffi.cast.type.z2c(Field);

    var abi_args: @Tuple(&types) = undefined;
    inline for (args, 0..) |value, i| abi_args[i] = ffi.cast.z2c(value);

    const result = ffi.msg.send(receiver, ffi.cast.type.z2c(Return), ffi.Sel.get(name), abi_args);
    return if (Return == bool) ffi.cast.c2z(result) else result;
}
