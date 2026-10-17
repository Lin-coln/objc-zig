const std = @import("std");
const objc = @import("../root.zig");

/// Class helpers for a wrapper whose type or type factory is named after its Objective-C class.
pub fn Class(comptime T: type) type {
    const class_name = comptime objc.utils.resolveTypeName(@typeName(T));

    return struct {
        /// Sends `alloc` to the class, returning an uninitialized instance to be sent an `init...` message.
        pub fn alloc() *T {
            return msgSend(?*T, "alloc", .{}).?;
        }

        /// Sends `new` to the class, returning a newly allocated and initialized instance.
        pub fn new() *T {
            return msgSend(?*T, "new", .{}).?;
        }

        /// Returns the Objective-C class bound to the wrapper type.
        pub fn getClass() *objc.rt.Class {
            return objc.rt.getClass(class_name).?;
        }

        /// Sends the selector named `sel` to the class itself (a class method).
        pub fn msgSend(comptime Return: type, sel: [:0]const u8, args: anytype) Return {
            return objc.rt.msgSend(getClass(), Return, objc.rt.Sel.registerName(sel), args);
        }

        /// Binds a void class method whose only argument is a block with signature `Function`.
        /// The context passed to the returned function must outlive every invocation of the handler.
        pub fn methodWithBlock(comptime sel: [:0]const u8, comptime Function: type) @TypeOf(MethodWithBlock(sel, Function).call) {
            return MethodWithBlock(sel, Function).call;
        }

        fn MethodWithBlock(comptime sel: [:0]const u8, comptime Function: type) type {
            const fn_info = switch (@typeInfo(Function)) {
                .@"fn" => |info| info,
                else => @compileError("methodWithBlock requires a block function type"),
            };
            if (fn_info.is_generic or fn_info.attrs.varargs)
                @compileError("methodWithBlock requires fixed, non-generic block parameters");

            return struct {
                pub fn call(comptime Context: type, ctx: Context, comptime handler: *const Callback(Context)) void {
                    const blk = objc.helpers.block.initWithContext(ctx, handler.*);
                    msgSend(void, sel, .{&blk});
                }

                fn Callback(comptime Context: type) type {
                    var params: [fn_info.param_types.len + 1]type = undefined;
                    params[0] = Context;
                    for (fn_info.param_types, 1..) |Param, i| params[i] = Param.?;
                    return @Fn(&params, &@splat(.{}), fn_info.return_type.?, .{});
                }
            };
        }
    };
}

test "helpers.Class: class messages, new and alloc" {
    const NSMutableData = opaque {};
    const h = Class(NSMutableData);
    const rt = objc.rt;
    const length = rt.Sel.registerName("length");
    const set_length = rt.Sel.registerName("setLength:");

    try std.testing.expectEqual(rt.getClass("NSMutableData").?, h.msgSend(*rt.Class, "class", .{}));

    const created = h.new();
    defer rt.release(@ptrCast(created));
    rt.msgSend(created, void, set_length, .{@as(usize, 5)});
    try std.testing.expectEqual(5, rt.msgSend(created, usize, length, .{}));

    const allocated = h.alloc();
    const initialized = rt.msgSend(allocated, ?*NSMutableData, rt.Sel.registerName("init"), .{}).?;
    defer rt.release(@ptrCast(initialized));
    rt.msgSend(initialized, void, set_length, .{@as(usize, 9)});
    try std.testing.expectEqual(9, rt.msgSend(initialized, usize, length, .{}));
}

test "helpers.Class: methodWithBlock sends a block and forwards its result" {
    const rt = objc.rt;
    const ZigHelpersBlockMethodTest = opaque {};
    const State = struct { value: i32, calls: usize = 0 };
    const Completion = objc.Block(*State, fn (i32, f64) i32);
    const Methods = struct {
        var result: i32 = 0;

        fn perform(_: *rt.Class, _: *rt.Sel, completion: *const Completion) callconv(.c) void {
            result = completion.invoke(completion, 3, 2.0);
        }

        fn complete(state: *State, value: i32, scale: f64) i32 {
            state.calls += 1;
            return @intFromFloat(@as(f64, @floatFromInt(state.value + value)) * scale);
        }
    };
    const class = rt.allocateClassPair(rt.getClass("NSObject").?, "ZigHelpersBlockMethodTest", 0).?;
    rt.registerClassPair(class);
    defer rt.disposeClassPair(class);
    const metaclass = rt.getMetaClass("ZigHelpersBlockMethodTest").?;
    try std.testing.expect(metaclass.addMethod(rt.Sel.registerName("performWithCompletion:"), &Methods.perform, "v@:@?"));

    const perform = Class(ZigHelpersBlockMethodTest).methodWithBlock("performWithCompletion:", fn (i32, f64) i32);
    var state: State = .{ .value = 7 };
    perform(*State, &state, Methods.complete);
    try std.testing.expectEqual(1, state.calls);
    try std.testing.expectEqual(20, Methods.result);
}
