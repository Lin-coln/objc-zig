pub const NSError = @import("NSError.zig").NSError;
pub const NSString = @import("NSString.zig").NSString;
pub const NSArray = @import("NSArray.zig").NSArray;
pub const NSDictionary = @import("NSDictionary.zig").NSDictionary;
pub const NSNumber = @import("NSNumber.zig").NSNumber;
pub const NSData = @import("NSData.zig").NSData;
pub const NSMutableData = @import("NSMutableData.zig").NSMutableData;

test {
    _ = @import("NSError.zig");
    _ = @import("NSString.zig");
    _ = @import("NSArray.zig");
    _ = @import("NSDictionary.zig");
    _ = @import("NSNumber.zig");
    _ = @import("NSData.zig");
    _ = @import("NSMutableData.zig");
}
