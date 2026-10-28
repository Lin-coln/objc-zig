const obzc = @import("obzc");
const Metadata = obzc.Metadata;

/// An Objective-C object conforming to the SCStreamDelegate protocol.
pub const SCStreamDelegate = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = obzc.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;
};
