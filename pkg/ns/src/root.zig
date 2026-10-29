const std = @import("std");
pub const NSError = @import("NSError.zig").NSError;
pub const NSString = @import("NSString.zig").NSString;
pub const NSArray = @import("NSArray.zig").NSArray;
pub const NSDictionary = @import("NSDictionary.zig").NSDictionary;
pub const NSNumber = @import("NSNumber.zig").NSNumber;
pub const NSData = @import("NSData.zig").NSData;
pub const NSMutableData = @import("NSMutableData.zig").NSMutableData;

test {
    std.testing.refAllDecls(@This());
}
