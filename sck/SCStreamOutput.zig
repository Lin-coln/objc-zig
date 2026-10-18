const objc = @import("objc");

/// An Objective-C object conforming to the SCStreamOutput protocol.
pub const SCStreamOutput = opaque {
    const h = objc.helpers.Object(@This());

    pub const retain = h.retain;
    pub const release = h.release;
};
