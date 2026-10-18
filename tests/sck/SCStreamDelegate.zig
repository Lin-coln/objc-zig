const objc = @import("objc");

/// An Objective-C object conforming to the SCStreamDelegate protocol.
pub const SCStreamDelegate = opaque {
    const h = objc.helpers.Object(@This());

    pub const retain = h.retain;
    pub const release = h.release;
};
