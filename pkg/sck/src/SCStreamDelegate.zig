const obzc = @import("obzc");

/// An Objective-C object conforming to the SCStreamDelegate protocol.
pub const SCStreamDelegate = opaque {
    const h = obzc.helpers.Object(@This());

    pub const retain = h.retain;
    pub const release = h.release;
};
