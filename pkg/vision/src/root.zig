pub const VNRequest = @import("VNRequest.zig").VNRequest;
pub const VNRecognizeTextRequest = @import("VNRecognizeTextRequest.zig").VNRecognizeTextRequest;
pub const VNRequestTextRecognitionLevel = @import("VNRecognizeTextRequest.zig").VNRequestTextRecognitionLevel;
pub const VNImageRequestHandler = @import("VNImageRequestHandler.zig").VNImageRequestHandler;
pub const VNRecognizedTextObservation = @import("VNRecognizedTextObservation.zig").VNRecognizedTextObservation;
pub const VNRecognizedText = @import("VNRecognizedText.zig").VNRecognizedText;

test {
    _ = @import("VNRequest.zig");
    _ = @import("VNRecognizeTextRequest.zig");
    _ = @import("VNImageRequestHandler.zig");
    _ = @import("VNRecognizedTextObservation.zig");
    _ = @import("VNRecognizedText.zig");
}
