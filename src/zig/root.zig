const objc = @import("objc.zig");

pub const Sel = @import("Sel.zig").Sel;
pub const Class = @import("Class.zig").Class;
pub const Object = @import("Object.zig").Object;
pub const Protocol = @import("Protocol.zig").Protocol;
pub const Ivar = @import("Ivar.zig").Ivar;
pub const Method = @import("Method.zig").Method;
pub const Property = @import("Property.zig").Property;
pub const Block = @import("Block.zig").Block;

pub const msgSend = objc.msgSend;
pub const msgSendSuper = objc.msgSendSuper;
pub const getClass = objc.getClass;
pub const getMetaClass = objc.getMetaClass;
pub const allocateClassPair = objc.allocateClassPair;
pub const registerClassPair = objc.registerClassPair;
pub const disposeClassPair = objc.disposeClassPair;
pub const getProtocol = objc.getProtocol;
pub const AssociationPolicy = objc.AssociationPolicy;
pub const setAssociatedObject = objc.setAssociatedObject;
pub const getAssociatedObject = objc.getAssociatedObject;
pub const enumerationMutation = objc.enumerationMutation;
pub const setEnumerationMutationHandler = objc.setEnumerationMutationHandler;
pub const retain = objc.retain;
pub const release = objc.release;
pub const autoreleasePoolPush = objc.autoreleasePoolPush;
pub const autoreleasePoolPop = objc.autoreleasePoolPop;

test {
    _ = @import("objc.zig");
    _ = @import("Sel.zig");
    _ = @import("Class.zig");
    _ = @import("Object.zig");
    _ = @import("Protocol.zig");
    _ = @import("Method.zig");
    _ = @import("Property.zig");
    _ = @import("Block.zig");
}
