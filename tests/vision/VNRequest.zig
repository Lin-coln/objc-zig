const objc = @import("objc");

pub const VNRequest = opaque {
    const h = objc.helpers.Object(@This());

    pub const retain = h.retain;
    pub const release = h.release;
};
