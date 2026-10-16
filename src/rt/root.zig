const objc = @import("objc/root.zig");

pub const Sel = @import("Sel.zig").Sel;
pub const Class = @import("Class.zig").Class;
pub const Object = @import("Object.zig").Object;
pub const Protocol = @import("Protocol.zig").Protocol;
pub const Ivar = @import("Ivar.zig").Ivar;
pub const Method = @import("Method.zig").Method;
pub const Property = @import("Property.zig").Property;
pub const Block = @import("Block.zig").Block;
pub const utils = @import("utils.zig");

pub const msgSend = objc.msgSend;
pub const msgSendSuper = objc.msgSendSuper;
pub const class = objc.class;
pub const metaClass = objc.metaClass;
pub const allocateClassPair = objc.allocateClassPair;
pub const registerClassPair = objc.registerClassPair;
pub const disposeClassPair = objc.disposeClassPair;
pub const protocol = objc.protocol;
pub const AssociationPolicy = objc.AssociationPolicy;
pub const setAssociatedObject = objc.setAssociatedObject;
pub const associatedObject = objc.associatedObject;
pub const enumerationMutation = objc.enumerationMutation;
pub const setEnumerationMutationHandler = objc.setEnumerationMutationHandler;
pub const retain = objc.retain;
pub const release = objc.release;
pub const autoreleasePoolPush = objc.autoreleasePoolPush;
pub const autoreleasePoolPop = objc.autoreleasePoolPop;

test {
    _ = @import("objc/root.zig");
    _ = @import("Sel.zig");
    _ = @import("Class.zig");
    _ = @import("Object.zig");
    _ = @import("Protocol.zig");
    _ = @import("Method.zig");
    _ = @import("Property.zig");
    _ = @import("Block.zig");
}
