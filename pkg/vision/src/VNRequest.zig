const obzc = @import("obzc");

pub const VNRequest = opaque {
    const h = obzc.helpers.Object(@This());

    pub const retain = h.retain;
    pub const release = h.release;
};
