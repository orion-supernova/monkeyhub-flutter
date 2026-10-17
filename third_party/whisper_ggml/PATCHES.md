# whisper_ggml 2.8.1, vendored

pub.dev whisper_ggml 2.8.1 (whisper.cpp v1.9.1) with the `example/` app
dropped, plus ggml-metal v1.9.1 for iOS and macOS (PATCH 10). Every change is marked `MONKEYHUB PATCH n` in
source.

There is ONE native tree: `android/src/whisper/` (whisper.cpp, json.hpp,
`main.cpp`, the `mh_*` decoder files). Android, Linux and Windows CMake
already built from it; the iOS and macOS pods now do too, through one-line
forwarders in `ios/Classes` and `macos/Classes` (PATCH 7). Upstream shipped
three byte-identical 4.3 MB copies of whisper.cpp, and a separate Apple
`main.cpp` that had drifted from the Android one.

## Bumping

Re-apply every patch below against the new version. The quick check that
nothing was lost: `grep -rn "MONKEYHUB PATCH" .` and `pubspec.yaml` must not
list `ffmpeg_kit_flutter_new_min`. After changing the set of native sources,
run `python3 tool/gen_apple_forwarders.py` from the package root. After
touching `ggml-metal.metal`, `ggml-metal-impl.h` or `ggml-common.h`, run
`python3 tool/gen_metal_embed.py` (and re-apply PATCH 10 to the copied
ggml-metal sources when bumping whisper.cpp: they come from
`ggml/src/ggml-metal/` of the matching whisper.cpp tag, which pub's
whisper_ggml does not ship).

## Patches

- **1, no ffmpeg.** `pubspec.yaml` drops `ffmpeg_kit_flutter_new_min`
  (tens of MB of ffmpeg in every build, no Windows/Linux implementation);
  `lib/src/whisper_audio_convert.dart` is deleted and no longer exported;
  `android/consumer-rules.pro` loses the ffmpeg-kit keep rules (upstream
  #16). Replaced by PATCH 2.

- **2, native decoder.** `int32_t mh_decode_to_wav16k(in, out)` turns any
  OS-decodable audio into a 16 kHz mono s16le WAV.
  - `mh_audio.h/.cpp` (all platforms): error codes; WAV input of any
    PCM/float/ADPCM layout via dr_wav (so OS decoders only see compressed
    containers); downmix by averaging; a streaming Kaiser windowed-sinc
    resampler (exact polyphase for rational ratios such as 160/441, cutoff
    at 0.92 x 8 kHz, about 80 dB stopband); the WAV writer; UTF-8 paths on
    Windows; the Linux stub returning `MH_ERR_NO_DECODER`.
  - `mh_decode_apple.cpp`: AudioToolbox `ExtAudioFile`, whose converter
    resamples to 16 kHz at max quality (podspecs add AudioToolbox and
    CoreFoundation).
  - `mh_decode_android.cpp`: `AMediaExtractor` + `AMediaCodec` (API 21+,
    links `mediandk`).
  - `mh_decode_windows.cpp`: Media Foundation `IMFSourceReader` to float
    PCM (links mfplat, mfreadwrite, mfuuid, ole32). Balances
    `CoInitializeEx` and tolerates an STA thread.
  - Linux: `lib/src/whisper_decode.dart` spawns `gst-launch-1.0`, then
    `ffmpeg`, when the native call reports `MH_ERR_NO_DECODER`.
  - Dart: `decodeToWav16k()` + `WhisperDecodeException`
    (`lib/src/whisper_decode.dart`, exported); `Whisper.transcribe` decodes
    anything that is not already a 16 kHz 16-bit WAV to `<audio>.16k.wav`
    and deletes it afterwards. `main.cpp` opens the WAV through a UTF-8
    path on Windows too.

- **3, detected language.** `main.cpp` adds `"language"`
  (`whisper_lang_str(whisper_full_lang_id(ctx))`) to the transcribe
  response; `WhisperTranscribeResponse.language` (hand-edited `.freezed.dart`
  and `.g.dart`, no build_runner).

- **4, `WhisperController.transcribe(modelPath:)`.** Exactly one of `model`
  and `modelPath`, as `transcribeLive` already had.

- **5, thread count.** `TranscribeRequest.threads` defaults to 0 (was 6);
  `main.cpp` maps <= 0 to `min(4, cores)` and clamps anything above the core
  count, for one-shot and live requests alike.

- **6, cancellation.** `Whisper.cancelTranscription()` /
  `WhisperController.cancelTranscription()` send `cancelTranscription`;
  `main.cpp` bumps a generation counter that every in-flight `transcribe`
  polls from whisper's `abort_callback`. A cancelled request answers
  `{"cancelled": true}` and `Whisper.transcribe` throws
  `WhisperCancelledException` (the controller returns null, as for any
  error). Requests started after the cancel are unaffected.

- **7, one native tree.** See the top. The podspecs compile
  `Classes/fwd_*.{c,cpp}` and search headers in `../android/src/whisper/...`.
  This also replaces the drifted Apple `main.cpp`, which rejected
  `language: "auto"` ("unknown language") and defaulted to `"id"`.

- **8, build settings.** iOS pod target 15.0 (was 15.6, above the app's
  15.0, so `pod install` refused it); macOS 12.0 (was 10.15, which Xcode
  26+'s libc++ warns about on every file); `NDEBUG=1` on Apple in every
  configuration (upstream's CMake Release has it; ggml's `assert()`s sat in
  hot loops); Android `ndkVersion` 28.2.13676358 (= `flutter.ndkVersion`;
  29 is not installed and AGP would download it), no 32-bit `x86` ABI
  (Flutter ships no x86 engine), explicit 16 KB page alignment.

- **9, whisper.cpp itself** (`whisper.cpp/src/whisper.cpp`):
  - Language detection encodes the first 30 s window; `whisper_full` then
    encoded the same window again. The main loop now reuses it, which halves
    `lang: 'auto'` latency for clips under 30 s (byte-identical output,
    checked on 5 s and 44 s clips in both segment modes).
  - The scheduler-based graph helper installs `abort_callback` on its
    backends (and clears it when none is passed), so a cancel stops within
    a graph node instead of after a whole encoder pass; language detection
    passes the callback too.

- **10, Metal on iOS and macOS.**
  - Sources: `whisper.cpp/ggml/src/ggml-metal/` copied from whisper.cpp
    v1.9.1 (pub's package has none). The shader is embedded as source
    (`GGML_METAL_EMBED_LIBRARY`) in the checked-in, generated
    `ggml-metal-embed.c` (`tool/gen_metal_embed.py`, the same sed merge
    upstream's CMake does at build time) and compiled by the OS at runtime.
    No precompiled metallib: Xcode 26+ ships the Metal toolchain as a
    separate download, so a `.metal` pod source could break the build.
  - Podspecs: `GGML_USE_METAL=1 GGML_METAL_EMBED_LIBRARY=1` (not on the
    iOS Simulator, which stays CPU-only at compile time; the forwarders for
    ggml-metal files are `#if defined(GGML_USE_METAL)`), Metal, MetalKit,
    Foundation frameworks, `requires_arc = false` (ggml-metal does manual
    retain/release).
  - `mh_gpu_apple.mm`: `mh_gpu_supported()` = MTLGPUFamilyApple7 (A14 / M1+,
    what ggml-metal's matrix kernels need), iOS 16+ / macOS 13+, not the
    simulator. Elsewhere the Metal registry exposes no device at all.
  - `ggml-metal-device.m`: shader library compiled lazily on first use
    instead of at device creation (the device exists from the first ggml
    call of the process, CPU-only requests included); tensor API off
    (upstream enables it only on M5/A19; untested, extra compiles);
    residency sets off (their keep-alive thread wakes every 5 ms for the
    life of the process). Embedded source read with an explicit length.
    `ggml-metal-context.m`: a failed library compile fails the backend
    instead of recompiling per context; `MH_TEST_HOOKS` (never set by the
    podspecs) can simulate a refused command buffer. `ggml-metal.cpp`:
    exposes `ggml_backend_set_abort_callback`, so cancel (PATCH 6/9) also
    works on Metal.
  - `whisper.cpp`: `whisper_mh_ctx_uses_gpu()`.
  - `main.cpp`: GPU when the request allows it (`"use_gpu"`, default
    true), `mh_set_gpu_allowed()` allows it (the app clears it while
    backgrounded: iOS refuses GPU work from the background) and the device
    is supported. A GPU run that fails (not a cancel) is retried once on a
    fresh CPU context and the failed one freed (ggml-metal keeps it in an
    error state); a GPU context whose Metal backend failed to start is
    reloaded as CPU. The model cache keys on the backend; live sessions
    stay CPU. Responses carry `"backend": "metal" | "cpu"` and
    `"gpu_fallback": true` after a retry. `mh_gpu_prewarm()` compiles the
    shaders ahead of time.
  - Dart: `setWhisperGpuAllowed`, `whisperGpuAvailable`,
    `prewarmWhisperGpu` (`lib/src/whisper_gpu.dart`),
    `WhisperTranscribeResponse.backend` / `.gpuFallback`.

Everything else (Dart live API, Linux/Windows CMake beyond the source and
link lines, whisper.cpp/ggml outside PATCH 9) is pub.dev 2.8.1.
