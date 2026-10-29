const std = @import("std");
const core = @import("core");
const ns = @import("ns");

test "NSDictionary: nested arrays survive their creators and autorelease pool" {
    const Strings = ns.NSArray(ns.NSString);
    const Dictionary = ns.NSDictionary(ns.NSString, Strings);
    const dictionary = created: {
        const pool = core.AutoReleasePool.create();
        defer pool.release();
        const key = ns.NSString.init("nested collection contents").?;
        defer key.release();
        const first = ns.NSString.init("first retained collection element").?;
        defer first.release();
        const second = ns.NSString.init("second retained collection element").?;
        defer second.release();
        const strings = Strings.init(&.{ first, second });
        defer strings.release();

        break :created Dictionary.init(&.{strings}, &.{key});
    };
    defer dictionary.release();

    // Look up an equal key created after the original key and pool were released.
    const key = ns.NSString.init("nested collection contents").?;
    defer key.release();
    const strings = dictionary.objectForKey(key).?;
    try std.testing.expectEqual(1, dictionary.count());
    try std.testing.expectEqual(2, strings.count());
    try std.testing.expectEqualStrings("first retained collection element", strings.objectAtIndex(0).utf8String());
    try std.testing.expectEqualStrings("second retained collection element", strings.objectAtIndex(1).utf8String());
}
