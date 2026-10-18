const objc = @import("objc");
const ns = @import("objc/ns");

pub const VNRecognizedText = opaque {
    const h = objc.helpers.Object(@This());

    pub const retain = h.retain;
    pub const release = h.release;

    pub const confidence = h.prop(f32, "confidence").getter;
    /// The string is borrowed from the recognized text.
    pub const string = h.prop(*ns.NSString, "string").getter;
};
