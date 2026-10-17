# whisper_ggml consumer rules — merged into the R8 configuration of every
# app that depends on this plugin.
#
# MONKEYHUB PATCH 1: the ffmpeg-kit keep rules (upstream issue #16) went
# with the ffmpeg-kit dependency.

# Keep native method names for JNI registration.
-keepclasseswithmembernames class * {
    native <methods>;
}

-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
