const obzc = @import("obzc");

/// An Objective-C object conforming to the SCStreamOutput protocol.
pub const SCStreamOutput = opaque {
    const h = obzc.helpers.Object(@This());

    pub const retain = h.retain;
    pub const release = h.release;
};
