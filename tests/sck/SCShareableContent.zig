const std = @import("std");
const dispatch = std.c.dispatch;
const objc = @import("objc");
const ns = @import("objc/ns");
const macos = @import("macos");
const SCWindow = @import("SCWindow.zig").SCWindow;

pub const SCShareableContent = opaque {
    const Self = @This();
    const h = objc.helpers.Object(Self);
    const cls = objc.helpers.Class(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const windows = h.prop(*ns.NSArray(SCWindow), "windows").getter;

    pub fn getShareableContent(completion_handler: anytype) void {
        cls.msgSend(void, "getShareableContentWithCompletionHandler:", .{completion_handler});
    }

    /// Returns retained content, or null on failure. The caller must release the result.
    pub fn getShareableContentSync() ?*Self {
        const semaphore = dispatch.semaphore_create(0) orelse return null;
        defer dispatch.release(semaphore.as_object());

        const State = struct {
            semaphore: dispatch.semaphore_t,
            content: ?*Self = null,
        };
        const Completion = objc.Block(*State, fn (?*Self, ?*ns.NSError) void);
        const complete = struct {
            fn f(block: *const Completion, content: ?*Self, err: ?*ns.NSError) callconv(.c) void {
                const state = block.context;
                const signal = state.semaphore;
                defer dispatch.release(signal.as_object());

                if (err == null) state.content = if (content) |value| value.retain() else null;
                _ = dispatch.semaphore_signal(signal);
            }
        }.f;

        var state: State = .{ .semaphore = semaphore };
        const handler = Completion.init(&state, &complete);
        // Keep the semaphore alive until the callback finishes signaling it.
        dispatch.retain(semaphore.as_object());
        getShareableContent(&handler);
        _ = dispatch.semaphore_wait(semaphore, .FOREVER);
        return state.content;
    }
};

test "SCShareableContent: getShareableContent invokes a Zig Block" {
    // This query needs Screen Recording permission. Preflight never requests it.
    if (!macos.CGPreflightScreenCaptureAccess()) return error.SkipZigTest;

    const Completion = objc.Block(void, fn (?*SCShareableContent, ?*ns.NSError) void);
    const State = struct {
        // Static storage remains valid if the callback arrives after the timeout.
        var ready: std.Io.Semaphore = .{};
        var received_content = false;
        var received_error = false;
        var error_code: isize = 0;

        fn complete(_: *const Completion, content: ?*SCShareableContent, err: ?*ns.NSError) callconv(.c) void {
            if (content) |value| {
                _ = value.windows().count();
                received_content = true;
            }
            if (err) |value| {
                received_error = true;
                error_code = value.code();
            }
            ready.post(std.testing.io);
        }
    };

    const handler = Completion.init({}, &State.complete);
    SCShareableContent.getShareableContent(&handler);
    try State.ready.waitTimeout(std.testing.io, .{ .duration = .{
        .raw = .fromSeconds(10),
        .clock = .awake,
    } });

    if (State.received_error) {
        std.debug.print("SCShareableContent failed with NSError code {d}\n", .{State.error_code});
        return error.ShareableContentFailed;
    }
    try std.testing.expect(State.received_content);
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
