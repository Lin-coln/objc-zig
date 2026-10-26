const obzc = @import("obzc");

/// An Objective-C object conforming to the SCStreamDelegate protocol.
pub const SCStreamDelegate = opaque {
    const Self = @This();
    const h = obzc.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;
};
