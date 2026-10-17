import 'dart:ffi';

import 'package:universal_io/io.dart';

/// MONKEYHUB PATCH 2: the plugin library, opened the same way by every
/// native entry point (`request`, `mh_decode_to_wav16k`). Apple platforms
/// link the pod into the process, so its symbols resolve from there.
DynamicLibrary openWhisperLibrary() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libwhisper.so');
  } else if (Platform.isWindows) {
    return DynamicLibrary.open('whisper_ggml.dll');
  } else if (Platform.isLinux) {
    return DynamicLibrary.open('libwhisper_ggml.so');
  } else {
    return DynamicLibrary.process();
  }
}
