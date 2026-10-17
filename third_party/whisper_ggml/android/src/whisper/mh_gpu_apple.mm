// MONKEYHUB PATCH 10: may whisper use the Metal backend on this device?
//
// ggml-metal v1.9.1 runs its matrix kernels only with simdgroup matrix
// multiply (MTLGPUFamilyApple7: A14 / M1 and newer). On older GPUs nearly
// every op would fall back to the CPU with copies in between, which is
// slower than plain CPU, so those devices stay on the CPU backend. Also
// CPU-only: the iOS Simulator (pods build it without GGML_USE_METAL; this
// is the runtime belt to that brace), and OS versions below iOS 16 /
// macOS 13, where the runtime Metal compiler would have to build the
// embedded shader at an older Metal language version nobody has tested.
//
// Compiled without ARC (the pod sets requires_arc = false for ggml-metal).
#if defined(__APPLE__)

#include <TargetConditionals.h>

#if defined(GGML_USE_METAL) && !TARGET_OS_SIMULATOR

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include <mutex>

extern "C" bool mh_gpu_supported(void)
{
    static bool supported = false;
    static std::once_flag once;
    std::call_once(once, [] {
        if (@available(iOS 16.0, macOS 13.0, *))
        {
            @autoreleasepool
            {
                id<MTLDevice> device = MTLCreateSystemDefaultDevice();
                if (device != nil)
                {
                    supported = [device supportsFamily:MTLGPUFamilyApple7];
                    [device release];
                }
            }
        }
    });
    return supported;
}

#else

extern "C" bool mh_gpu_supported(void)
{
    return false;
}

#endif
#endif // __APPLE__
