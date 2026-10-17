const std = @import("std");
const dispatch = std.c.dispatch;
const objc = @import("objc");
const ns = @import("objc/ns");
const macos = @import("macos");
const SCWindow = @import("SCWindow.zig").SCWindow;

pub const SCShareableContent = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const windows = h.prop(*ns.NSArray(SCWindow), "windows").getter;

    /// The context pointer must remain valid until the completion handler returns.
    pub const getShareableContent = h.cls.methodWithCallback(
        "getShareableContentWithCompletionHandler:",
        fn (fn (?*Self, ?*ns.NSError) void) void,
    );

    /// Returns retained content, or null on failure. The caller must release the result.
    pub fn getShareableContentSync() ?*Self {
        const semaphore = dispatch.semaphore_create(0) orelse return null;
        defer dispatch.release(semaphore.as_object());

        const State = struct {
            semaphore: dispatch.semaphore_t,
            content: ?*Self = null,
        };

        var state: State = .{ .semaphore = semaphore };
        // Keep the semaphore alive until the callback finishes signaling it.
        dispatch.retain(semaphore.as_object());
        getShareableContent(&state, struct {
            fn f(s: *State, content: ?*Self, err: ?*ns.NSError) void {
                const signal = s.semaphore;
                defer dispatch.release(signal.as_object());

                if (err == null) s.content = if (content) |value| value.retain() else null;
                _ = dispatch.semaphore_signal(signal);
            }
        }.f);
        _ = dispatch.semaphore_wait(semaphore, .FOREVER);
        return state.content;
    }
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

test "SCShareableContent: getShareableContentSync returns retained content" {
    if (!macos.CGPreflightScreenCaptureAccess()) return error.SkipZigTest;

    const content = SCShareableContent.getShareableContentSync() orelse return error.ShareableContentFailed;
    defer content.release();

    const windows = content.windows();
    for (0..windows.count()) |index| {
        const window = windows.objectAtIndex(index);
        try std.testing.expect(window.windowID() != macos.kCGNullWindowID);
        _ = window.owningApplication();
        if (window.title()) |title| _ = title.length();
    }
}
