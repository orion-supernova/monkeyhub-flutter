// MONKEYHUB PATCH 10: Metal backend controls (iOS/macOS). Everywhere else
// the native calls exist too and report no GPU.
import 'dart:ffi';
import 'dart:isolate';

import 'whisper_native.dart';

typedef _SetAllowedNative = Void Function(Int32 allowed);
typedef _SetAllowedDart = void Function(int allowed);
typedef _IntNative = Int32 Function();
typedef _IntDart = int Function();

/// Allow or bar the GPU for transcriptions that start from now on.
///
/// iOS rejects GPU work from a backgrounded app, so call this with `false`
/// as soon as the app leaves the foreground (`AppLifecycleState.inactive`,
/// `hidden` or `paused`) and with `true` on `resumed`. A transcription that
/// is already running on the GPU when the app goes to the background fails
/// its next GPU submission and is retried once on the CPU by the native
/// side (the response then has `gpuFallback == true`); it is not lost.
///
/// Synchronous and cheap (one atomic store): safe to call from the UI
/// isolate in a lifecycle callback.
void setWhisperGpuAllowed(bool allowed) {
  openWhisperLibrary()
      .lookupFunction<_SetAllowedNative, _SetAllowedDart>('mh_set_gpu_allowed')
      .call(allowed ? 1 : 0);
}

/// True when a transcription started now would run on the GPU: an Apple7+
/// GPU (A14 / M1 and newer) on iOS 16+ / macOS 13+, not the iOS Simulator,
/// and [setWhisperGpuAllowed] not set to false. Synchronous.
bool whisperGpuAvailable() {
  return openWhisperLibrary()
          .lookupFunction<_IntNative, _IntDart>('mh_gpu_available')
          .call() ==
      1;
}

/// Compile the Metal shaders now, off the calling isolate, instead of
/// inside the first transcription. The first compile after an install or
/// an OS update takes seconds (about 10 s on an M1); the OS caches it, so
/// later launches take milliseconds. Call it once while the app is in the
/// foreground, e.g. after the model is downloaded or at startup when
/// transcription is enabled. Completes with false where there is no usable
/// GPU (it then costs nothing) or the shaders failed to compile, in which
/// case transcriptions run on the CPU.
Future<bool> prewarmWhisperGpu() {
  return Isolate.run(
    () =>
        openWhisperLibrary()
            .lookupFunction<_IntNative, _IntDart>('mh_gpu_prewarm')
            .call() ==
        1,
  );
}
