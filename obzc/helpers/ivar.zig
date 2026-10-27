const std = @import("std");
const ffi = @import("../ffi/root.zig");
const utils = @import("../utils/root.zig");
const c = ffi.c;
const Class = ffi.Class;

pub fn ivar(comptime T: type) type {
    // const class_name = comptime utils.resolveTypeName(@typeName(T));

    return struct {
        pub fn of(comptime name: [:0]const u8, comptime P: type) type {
            return struct {
                pub fn getter(self: *T) P {
                    return get(self, P, name);
                }
                pub fn setter(self: *T, value: P) void {
                    set(self, P, name, value);
                }
            };
        }

        pub fn get(self: *T, comptime P: type, name: [:0]const u8) P {
            var raw: ?*anyopaque = null;
            _ = c.object_getInstanceVariable(@ptrCast(self), name, &raw).?;
            const value: P = @ptrCast(@alignCast(raw.?));
            return value;
        }

        pub fn set(self: *T, comptime P: type, comptime name: [:0]const u8, value: P) void {
            _ = c.object_setInstanceVariable(@ptrCast(self), name, value).?;
        }
    };
}
