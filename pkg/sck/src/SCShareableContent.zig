const std = @import("std");
const obzc = @import("obzc");
const ns = @import("obzc-ns");
const macos = @import("macos/abi");
const SCWindow = @import("SCWindow.zig").SCWindow;

pub const SCShareableContent = opaque {
    const Self = @This();
    const h = obzc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const windows = h.prop(*ns.NSArray(SCWindow), "windows").getter;

    /// The context pointer must remain valid until the completion handler returns.
    pub const getShareableContent = h.cls.methodWithCallback(
        "getShareableContentWithCompletionHandler:",
        fn (fn (?*Self, ?*ns.NSError) void) void,
    );

    /// Returns retained content. The caller must release the result.
    pub const getShareableContentSync = h.cls.methodSync(
        "getShareableContentWithCompletionHandler:",
        fn () anyerror!*Self,
    );
};

test "SCShareableContent: getShareableContent invokes a Zig Block" {
    // This query needs Screen Recording permission. Preflight never requests it.
    if (!macos.CGPreflightScreenCaptureAccess()) return error.SkipZigTest;

    const State = struct {
        ready: std.Io.Semaphore = .{},
        received_content: bool = false,
        received_error: bool = false,
        error_code: isize = 0,

        fn complete(state: *@This(), content: ?*SCShareableContent, err: ?*ns.NSError) void {
            if (content) |value| {
                _ = value.windows().count();
                state.received_content = true;
            }
            if (err) |value| {
                state.received_error = true;
                state.error_code = value.code();
            }
            state.ready.post(std.testing.io);
        }
    };

    const Storage = struct {
        // Static storage remains valid if the callback arrives after the timeout.
        var state: State = .{};
    };
    const state = &Storage.state;
    SCShareableContent.getShareableContent(state, State.complete);
    try state.ready.waitTimeout(std.testing.io, .{ .duration = .{
        .raw = .fromSeconds(10),
        .clock = .awake,
    } });

    if (state.received_error) {
        std.debug.print("SCShareableContent failed with NSError code {d}\n", .{state.error_code});
        return error.ShareableContentFailed;
    }
    try std.testing.expect(state.received_content);
}
