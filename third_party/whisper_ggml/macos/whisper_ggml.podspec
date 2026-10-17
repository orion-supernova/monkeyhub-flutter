Pod::Spec.new do |s|
  s.name             = 'whisper_ggml'
  s.version          = '1.0.0'
  s.summary          = 'A new Flutter FFI plugin project.'
  s.description      = <<-DESC
A new Flutter FFI plugin project.
                       DESC
  s.homepage         = 'https://github.com/sk3llo/whisper_ggml'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'www.antonkarpenko.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  # MONKEYHUB PATCH 7: Classes/ holds one-line forwarders into the single
  # native tree at ../android/src/whisper (shared with Android, Linux and
  # Windows) instead of a private copy of whisper.cpp per platform. Dart
  # binds through FFI symbol lookup, so no header is public.
  s.source_files = 'Classes/**/*.{cpp,c,m,mm}'
  # MONKEYHUB PATCH 10: ggml-metal's Objective-C does manual retain/release
  # (as upstream's CMake build compiles it); ARC would reject it.
  s.requires_arc = false
  s.dependency 'FlutterMacOS'
  # MONKEYHUB PATCH 8: 12.0 = the app's target; Xcode 26+'s libc++ warns
  # on every C++ file that 10.15 is no longer supported.
  s.platform = :osx, '12.0'
  s.library = 'c++'
  # MONKEYHUB PATCH 2: AudioToolbox + CoreFoundation for the decoder.
  # MONKEYHUB PATCH 10: Metal, MetalKit, Foundation for ggml-metal.
  s.frameworks = 'Accelerate', 'AudioToolbox', 'CoreFoundation', 'Metal', 'MetalKit', 'Foundation'
  # Build settings stay pod-scoped: s.xcconfig would also put them in the
  # app's Pods-Runner xcconfig, where they can override the app's own (#32).
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20',
    # whisper.cpp v1.9.1 include roots
    # MONKEYHUB PATCH 7: the shared tree (see source_files).
    'HEADER_SEARCH_PATHS' => [
      '"$(PODS_TARGET_SRCROOT)/../android/src/whisper/whisper.cpp/include"',
      '"$(PODS_TARGET_SRCROOT)/../android/src/whisper/whisper.cpp/ggml/include"',
      '"$(PODS_TARGET_SRCROOT)/../android/src/whisper/whisper.cpp/ggml/src"',
      '"$(PODS_TARGET_SRCROOT)/../android/src/whisper/whisper.cpp/ggml/src/ggml-cpu"',
      '"$(PODS_TARGET_SRCROOT)/../android/src/whisper/whisper.cpp/src"',
    ].join(' '),
    # MONKEYHUB PATCH 8: NDEBUG=1, as upstream's Release CMake build has;
    # without it ggml's assert()s stay live in hot loops in every config.
    # MONKEYHUB PATCH 10: GGML_USE_METAL registers the Metal backend;
    # GGML_METAL_EMBED_LIBRARY compiles the embedded shader source
    # (ggml-metal-embed.c) at runtime, so no Metal toolchain is needed.
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) NDEBUG=1 GGML_USE_CPU=1 GGML_USE_ACCELERATE=1 ACCELERATE_NEW_LAPACK=1 ACCELERATE_LAPACK_ILP64=1 GGML_VERSION=\"1.9.1\" GGML_COMMIT=\"whisper.cpp-v1.9.1\" WHISPER_VERSION=\"1.9.1\" GGML_USE_METAL=1 GGML_METAL_EMBED_LIBRARY=1 GGML_METAL_NDEBUG=1',
    # keep inference usable in debug builds
    'GCC_OPTIMIZATION_LEVEL' => '3',
  }
  s.swift_version = '5.0'
end