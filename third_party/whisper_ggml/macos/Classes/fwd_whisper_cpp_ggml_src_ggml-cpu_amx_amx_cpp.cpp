// MONKEYHUB PATCH 7: forwarder. The one native tree is android/src/whisper
// (also built by the Android, Linux and Windows CMake files); CocoaPods
// cannot list sources outside the pod directory, so each is compiled
// through a one-line include. Regenerate with tool/gen_apple_forwarders.py.
#include "../../android/src/whisper/whisper.cpp/ggml/src/ggml-cpu/amx/amx.cpp"
