const obzc = @import("obzc");

pub const MTLCompileOptions = opaque {
    const h = obzc.helpers.Object(@This());

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;
};
