const obzc = @import("obzc");

pub const MTLCompileOptions = opaque {
    const Self = @This();
    const h = obzc.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;
};
