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
    pub const getShareableContent = h.cls.m.withCallback(
        "getShareableContentWithCompletionHandler:",
        fn (fn (?*Self, ?*ns.NSError) void) void,
    );

    /// Returns retained content. The caller must release the result.
    pub const getShareableContentSync = h.cls.m.withSync(
        "getShareableContentWithCompletionHandler:",
        fn () anyerror!*Self,
    );
};

test "SCShareableContent: getShareableContent invokes a Zig completion" {
    // Preflight checks Screen Recording permission without requesting it.
    if (!macos.CGPreflightScreenCaptureAccess()) return error.SkipZigTest;
    const pool = obzc.AutoReleasePool.create();
    defer pool.release();

    const State = struct {
        ready: std.Io.Semaphore = .{},
        received_content: bool = false,
        error_code: ?isize = null,

        fn complete(state: *@This(), content: ?*SCShareableContent, err: ?*ns.NSError) void {
            state.received_content = content != null;
            if (err) |value| state.error_code = value.code();
            state.ready.post(std.testing.io);
        }
    };

    const Storage = struct {
        // The SDK may finish after the timeout; its context must remain valid.
        var state: State = .{};
    };
    const state = &Storage.state;
    SCShareableContent.getShareableContent(state, State.complete);
    try state.ready.waitTimeout(std.testing.io, .{ .duration = .{
        .raw = .fromSeconds(10),
        .clock = .awake,
    } });

    if (state.error_code) |code| {
        std.debug.print("SCShareableContent failed with NSError code {d}\n", .{code});
        return error.ShareableContentFailed;
    }
    try std.testing.expect(state.received_content);
}
