const obzc = @import("obzc");

/// An Objective-C object conforming to the SCStreamOutput protocol.
pub const SCStreamOutput = opaque {
    const Self = @This();
    const h = obzc.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;
};
