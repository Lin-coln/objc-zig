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

        /// Binds a class method to the signature `Shape`, accepting its arguments directly.
        /// Supports up to thirteen method arguments through `utils.spreadArgs`.
        pub fn method(
            comptime name: [:0]const u8,
            comptime Shape: type,
        ) *const Shape {
            const fn_info = switch (@typeInfo(Shape)) {
                .@"fn" => |info| info,
                else => @compileError("method Shape must be a function type"),
            };
            if (fn_info.is_generic or fn_info.attrs.varargs)
                @compileError("method Shape must have fixed, non-generic parameters");

            const Static = struct {
                fn call(args: std.meta.ArgsTuple(Shape)) fn_info.return_type.? {
                    return msgSend(fn_info.return_type.?, name, args);
                }
            };

            return objc.utils.spreadArgs(Static.call, fn_info.attrs.@"callconv");
        }

        /// Binds a void class method whose last Shape parameter is a block function type.
        /// The returned function takes context, the preceding arguments, then a comptime handler.
        /// Captured context must outlive every invocation of the block handler.
        pub fn methodWithCallback(
            comptime name: [:0]const u8,
            comptime Shape: type,
        ) @TypeOf(MethodWithCallback(name, Shape).call) {
            return MethodWithCallback(name, Shape).call;
        }

        fn MethodWithCallback(comptime name: [:0]const u8, comptime Shape: type) type {
            const shape_info = switch (@typeInfo(Shape)) {
                .@"fn" => |info| info,
                else => @compileError("methodWithCallback Shape must be a function type"),
            };
            if (shape_info.attrs.varargs)
                @compileError("methodWithCallback Shape cannot have C variadic parameters");
            if (shape_info.return_type != void)
                @compileError("methodWithCallback Shape must return void");
            if (shape_info.param_types.len == 0)
                @compileError("methodWithCallback Shape must end with a block function type");

            const last = shape_info.param_types.len - 1;
            const Function = shape_info.param_types[last] orelse
                @compileError("methodWithCallback Shape must end with a known block function type");
            if (@typeInfo(Function) != .@"fn")
                @compileError("methodWithCallback Shape must end with a block function type");
            const fn_info = @typeInfo(Function).@"fn";
            if (fn_info.is_generic or fn_info.attrs.varargs)
                @compileError("methodWithCallback requires fixed, non-generic block parameters");

            const Args = blk: {
                var params: [last]type = undefined;
                for (shape_info.param_types[0..last], 0..) |Param, i| params[i] = Param orelse
                    @compileError("methodWithCallback Shape parameters must have explicit types");
                break :blk @Tuple(&params);
            };

            return struct {
                pub const call = objc.utils.spreadArgsWithContext(Args, Callback, invoke);

                fn invoke(ctx: anytype, args: Args, comptime handler: *const Callback(@TypeOf(ctx))) void {
                    const blk = objc.helpers.block.initWithContext(ctx, handler.*);
                    msgSend(void, name, args ++ .{&blk});
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

test "helpers.Class: methodWithCallback sends a block and forwards its result" {
    const rt = objc.rt;
    const ZigHelpersBlockMethodTest = opaque {};
    const State = struct { value: i32, calls: usize = 0 };
    const Completion = objc.Block(*State, fn (i32, f64) i32);
    const Methods = struct {
        var result: i32 = 0;

        fn perform(_: *rt.Class, _: *rt.Sel, completion: *const Completion) callconv(.c) void {
            result = completion.invoke(completion, 3, 2.0);
        }

        fn performWithArgs(_: *rt.Class, _: *rt.Sel, value: i32, scale: f64, completion: *const Completion) callconv(.c) void {
            result = completion.invoke(completion, value, scale);
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
    try std.testing.expect(metaclass.addMethod(rt.Sel.registerName("performWithValue:scale:completion:"), &Methods.performWithArgs, "v@:id@?"));

    const perform = Class(ZigHelpersBlockMethodTest).methodWithCallback("performWithCompletion:", fn (fn (i32, f64) i32) void);
    var state: State = .{ .value = 7 };
    perform(&state, Methods.complete);
    try std.testing.expectEqual(1, state.calls);
    try std.testing.expectEqual(20, Methods.result);

    const perform_with_args = Class(ZigHelpersBlockMethodTest).methodWithCallback("performWithValue:scale:completion:", fn (i32, f64, fn (i32, f64) i32) void);
    perform_with_args(&state, 5, 2.5, Methods.complete);
    try std.testing.expectEqual(2, state.calls);
    try std.testing.expectEqual(30, Methods.result);
}

test "helpers.Class: method forwards typed arguments and returns an object" {
    const rt = objc.rt;
    const pool = rt.autoreleasePoolPush();
    defer rt.autoreleasePoolPop(pool);
    const NSMutableData = opaque {};
    const create = Class(NSMutableData).method("dataWithLength:", fn (usize) *rt.Object);
    try std.testing.expect(@TypeOf(create) == *const fn (usize) *rt.Object);
    const data = create(7);
    try std.testing.expectEqual(7, rt.msgSend(data, usize, rt.Sel.registerName("length"), .{}));
    const get_class = Class(NSMutableData).method("class", fn () *rt.Class);
    try std.testing.expectEqual(rt.getClass("NSMutableData").?, get_class());
}
