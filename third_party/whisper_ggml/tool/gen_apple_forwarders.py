#!/usr/bin/env python3
# MONKEYHUB PATCH 7: regenerates ios/Classes and macos/Classes, the one-line
# forwarders CocoaPods compiles into the single native tree at
# android/src/whisper. Run from the package root after changing the set of
# native sources (e.g. re-vendoring whisper.cpp):
#   python3 tool/gen_apple_forwarders.py
import glob
import os

ROOT = 'android/src/whisper'
HEADER = (
    '// MONKEYHUB PATCH 7: forwarder. The one native tree is android/src/whisper\n'
    '// (also built by the Android, Linux and Windows CMake files); CocoaPods\n'
    '// cannot list sources outside the pod directory, so each is compiled\n'
    '// through a one-line include. Regenerate with tool/gen_apple_forwarders.py.\n'
)

sources = sorted(
    glob.glob(ROOT + '/whisper.cpp/**/*.c', recursive=True)
    + glob.glob(ROOT + '/whisper.cpp/**/*.cpp', recursive=True)
    + glob.glob(ROOT + '/whisper.cpp/**/*.m', recursive=True)
) + [ROOT + '/main.cpp', ROOT + '/mh_audio.cpp', ROOT + '/mh_decode_apple.cpp',
     ROOT + '/mh_gpu_apple.mm']

# MONKEYHUB PATCH 10: ggml-metal is only built where the podspec defines
# GGML_USE_METAL (devices and macOS, not the iOS Simulator).
METAL_DIR = '/ggml/src/ggml-metal/'

for platform in ('ios', 'macos'):
    out = os.path.join(platform, 'Classes')
    os.makedirs(out, exist_ok=True)
    for old in glob.glob(os.path.join(out, 'fwd_*')):
        os.remove(old)
    for src in sources:
        rel = os.path.relpath(src, ROOT)
        stem, ext = os.path.splitext(rel)
        # Unique basenames (extension folded in): ggml.c and ggml.cpp would
        # otherwise both compile to ggml.o.
        name = 'fwd_' + stem.replace('/', '_').replace('.', '_') + '_' + ext[1:] + ext
        include = '#include "../../android/src/whisper/%s"\n' % rel
        if METAL_DIR in src:
            include = '#if defined(GGML_USE_METAL)\n' + include + '#endif\n'
        with open(os.path.join(out, name), 'w') as f:
            f.write(HEADER + include)
print('%d sources forwarded per platform' % len(sources))
