# R8 rules for release builds.
#
# Note this file did not exist before, which surprised everyone: release APKs
# ARE minified, obfuscated and resource-shrunk, but nothing in
# android/app/build.gradle.kts says so. The Flutter Gradle plugin sets
# isMinifyEnabled/isShrinkResources itself for release, and it wires THIS file
# in automatically if it exists (see flutter_tools/gradle FlutterPlugin.kt).
# So creating it is enough — no build.gradle.kts change is needed.
#
# Keep rules for the call stack (org.webrtc.*, com.cloudwebrtc.*,
# com.hiennv.flutter_callkit_incoming.*), Firebase and OneSignal all arrive from
# those libraries' own consumer rules, so they are deliberately NOT repeated
# here. Verified against build/app/outputs/mapping/release/usage.txt: nothing
# real was being stripped from any of them.
#
# What was actually missing was the ability to READ a crash from a shipped
# build.

# Retain enough of the debug metadata that a release stack trace has file names
# and line numbers instead of "Unknown Source". Without these two, an obfuscated
# native/Kotlin crash on a user's phone is undiagnosable even with mapping.txt —
# which is exactly the position this project was in when calls started crashing.
# -renamesourcefileattribute keeps the original file names out of the artifact
# while leaving the line-number table intact, so retrace still works.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep the *names* of the classes that appear in call-path crash reports so the
# frames are legible at a glance, before anyone goes looking for the matching
# mapping.txt. Names only: these stay shrunk and optimized, so the cost is a
# few KB.
-keepnames class com.walhallaa.chattest20241220.** { *; }
-keepnames class com.hiennv.flutter_callkit_incoming.** { *; }
