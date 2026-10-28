const obzc = @import("obzc");
const Metadata = obzc.Metadata;

pub const MTLCompileOptions = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = obzc.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;
    pub const new = h.cls.new;
};
