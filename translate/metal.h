#ifndef OBJC_ZIG_METAL_H
#define OBJC_ZIG_METAL_H

// Metal's public headers contain Objective-C declarations and cannot be
// translated as C. This C ABI subset follows the corresponding SDK headers.
// TODO: Replace manual declarations with a small libclang-based extractor:
// parse the official Objective-C headers, select the required symbols and their
// dependencies, and emit a pure C header for addTranslateC (macos/mtl-abi).
// Extract enum types/values, record layouts, typedefs and C function prototypes;
// keep Objective-C class/protocol/method wrappers outside the generated ABI.

// MTLPixelFormat.h, MTLTexture.h and MTLResource.h (NSUInteger).
typedef unsigned long MTLPixelFormat;
enum {
    MTLPixelFormatInvalid = 0,
    MTLPixelFormatBGRA8Unorm = 80,
    MTLPixelFormatRGBA16Float = 115,
};
typedef unsigned long MTLTextureUsage;
enum {
    MTLTextureUsageShaderRead = 0x0001,
    MTLTextureUsageRenderTarget = 0x0004,
};
typedef unsigned long MTLStorageMode;
enum {
    MTLStorageModeShared = 0,
    MTLStorageModePrivate = 2,
};

// MTLLibrary.h (NSUInteger).
typedef unsigned long MTLFunctionType;
enum {
    MTLFunctionTypeVertex = 1,
    MTLFunctionTypeFragment = 2,
    MTLFunctionTypeKernel = 3,
};

// MTLRenderPass.h.
typedef struct {
    double red, green, blue, alpha;
} MTLClearColor;
typedef unsigned long MTLLoadAction;
enum {
    MTLLoadActionDontCare = 0,
    MTLLoadActionLoad = 1,
    MTLLoadActionClear = 2,
};
typedef unsigned long MTLStoreAction;
enum {
    MTLStoreActionDontCare = 0,
    MTLStoreActionStore = 1,
};

// MTLRenderCommandEncoder.h and MTLCommandBuffer.h (NSUInteger).
typedef unsigned long MTLPrimitiveType;
enum { MTLPrimitiveTypeTriangleStrip = 4 };
typedef unsigned long MTLCommandBufferStatus;
enum {
    MTLCommandBufferStatusCompleted = 4,
    MTLCommandBufferStatusError = 5,
};

// MTLDevice.h: nullable, retained id<MTLDevice>.
struct objc_object;
extern struct objc_object *MTLCreateSystemDefaultDevice(void);

#endif
