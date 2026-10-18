const message = @import("message.zig");
const registry = @import("registry.zig");
const object = @import("object.zig");
const memory = @import("memory.zig");

pub const msgSend = message.msgSend;
pub const msgSendSuper = message.msgSendSuper;

pub const getClass = registry.getClass;
pub const getMetaClass = registry.getMetaClass;
pub const allocateClassPair = registry.allocateClassPair;
pub const registerClassPair = registry.registerClassPair;
pub const disposeClassPair = registry.disposeClassPair;
pub const getProtocol = registry.getProtocol;

pub const AssociationPolicy = object.AssociationPolicy;
pub const setAssociatedObject = object.setAssociatedObject;
pub const getAssociatedObject = object.getAssociatedObject;
pub const enumerationMutation = object.enumerationMutation;
pub const setEnumerationMutationHandler = object.setEnumerationMutationHandler;

pub const retain = memory.retain;
pub const release = memory.release;
pub const autoreleasePoolPush = memory.autoreleasePoolPush;
pub const autoreleasePoolPop = memory.autoreleasePoolPop;

test {
    _ = @import("message.zig");
    _ = @import("registry.zig");
    _ = @import("object.zig");
    _ = @import("memory.zig");
}
