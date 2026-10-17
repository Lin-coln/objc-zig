// Keep objc_object opaque: tagged pointers do not satisfy isa's alignment.
typedef struct objc_class *Class;
typedef struct objc_object *id;
#define OBJC_TYPES_DEFINED 1
#include <objc/objc.h>
#undef OBJC_TYPES_DEFINED

#include <objc/runtime.h>
#include <objc/message.h>
#include <Block.h>

// Apple Block ABI constants, absent from the public Block.h.
// Values and names follow libclosure's Block_private.h.
enum {
    BLOCK_HAS_COPY_DISPOSE = 1 << 25,
    BLOCK_USE_STRET = 1 << 29,
    BLOCK_HAS_SIGNATURE = 1 << 30,
    BLOCK_FIELD_IS_OBJECT = 3,
};

// The following functions are exported by libobjc but are not declared in any
// public SDK header. Their declarations are copied from runtime/objc-internal.h
// in Apple's objc4 source.
OBJC_EXPORT id _Nullable objc_retain(id _Nullable obj);
OBJC_EXPORT void objc_release(id _Nullable obj);
OBJC_EXPORT void * _Nonnull objc_autoreleasePoolPush(void);
OBJC_EXPORT void objc_autoreleasePoolPop(void * _Nonnull context);
