const core = @import("core");
const Metadata = core.Metadata;
const ns = @import("obzc-ns");

pub const VNRecognizedText = opaque {
    pub const metadata = Metadata.obj;
    const Self = @This();
    const h = core.h(Self);

    pub const retain = h.retain;
    pub const release = h.release;

    pub const confidence = h.prop("confidence", f32).getter;
    /// The string is borrowed from the recognized text.
    pub const string = h.prop("string", *ns.NSString).getter;
};
