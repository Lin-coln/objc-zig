const objc = @import("objc");

pub const MTLCompileOptions = opaque {
    const h = objc.helpers.Object(@This());

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;
};
