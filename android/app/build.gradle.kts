// Must be imported (not fully qualified inline): inside this script the bare
// `java` identifier resolves to the Java plugin extension, not the package.
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Upload-key signing (android/key.properties, gitignored; keystore lives
// outside the repo at ~/keystores/monkeyhub_upload.jks). Absent file →
// release falls back to debug signing so `flutter run --release` still works
// on machines without the key. deploy.sh won't start an Android build without
// key.properties and the keystore it names, and Play rejects a debug-signed
// bundle outright, so that fallback can't reach users.
//
// THREE certificates sign this app, and Google Sign-In needs ALL THREE
// registered as SHA-1 fingerprints in Firebase console → Project settings →
// Your apps → Android. Not a style rule — Android's Credential Manager
// validates package name + signing certificate against the Android OAuth
// clients in GCP project monkeyhub-2b2c6, so a build signed by a cert that
// isn't registered cannot sign in at all:
//
//   1. Debug keystore   (~/.android/debug.keystore) — `flutter run`
//   2. Upload key       (the keystore above)        — direct APK/AAB installs
//   3. Play App Signing (Google's own re-signing key, NOT the upload key)
//      — every user on ANY Play track, internal testing included.
//      Read it from Play Console → Test and release → App integrity →
//      Play app signing. This is the one that gets forgotten, and forgetting
//      it breaks exactly the users you cannot reproduce locally.
//
// Get 1 and 2 with:
//   keytool -list -v -keystore <path> -alias <alias>
//
// iOS is immune to all of this — it authenticates on bundle id and the
// reversed-client-id URL scheme, no certificate involved. So "Google login
// works on iOS but not Android" is this list being incomplete until proven
// otherwise; it is not a Dart-side bug. `google-services.json` grows a
// `client_type: 1` block once at least one fingerprint is registered, which
// makes that file a quick way to confirm the registration landed (the sign-in
// path itself reads the client id from env.local, not from that file).
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasUploadKey = keystoreProperties.containsKey("storeFile")

android {
    // Note: Android applicationId disallows '-' in package segments,
    // so we drop the hyphen from v02's iOS bundle id (com.walhallaa.chatTest-20241220)
    // while keeping the same vendor namespace.
    namespace = "com.walhallaa.chattest20241220"
    // flutter_webrtc transitively pulls androidx.camera 1.5.x + androidx.core
    // 1.18.x, both of which need compileSdk >= 36.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.walhallaa.chattest20241220"
        minSdk = flutter.minSdkVersion
        // Play rejects the release outright below 35 ("Target SDK of artifact
        // is too low"). 36 rather than 35 because the API 36 deadline is
        // 2026-08-31 — a month out — and both levels enforce edge-to-edge
        // anyway, so 35 would buy nothing but a second forced bump.
        targetSdk = 36
        // pubspec pins the build suffix at +1 (project convention: the patch
        // IS the user-facing build number), but Play/side-load upgrades need
        // a strictly increasing versionCode — derive it from the version name
        // instead: 1.3.22 → 10322.
        versionName = flutter.versionName
        versionCode = flutter.versionName.split(".").let { p ->
            p[0].toInt() * 10000 + p[1].toInt() * 100 + p[2].substringBefore("+").toInt()
        }
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("upload")
            } else {
                // No key.properties on this machine — keep `flutter run
                // --release` working. Not shippable (deploy.sh enforces).
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // FCM for the direct data-only call push (CallFcmService). OneSignal keeps
    // its own bundled FCM transport; this dependency is for OUR service only.
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")

    // VideoPlayerActivity — the OS video player a tapped video message opens.
    //
    // media3-exoplayer already arrives transitively via video_player_android,
    // but it is declared here anyway: this module compiles against it directly,
    // and a plugin's transitive graph is not a dependency contract — dropping
    // or upgrading video_player would break an unrelated Kotlin file with no
    // hint as to why. media3-ui (PlayerView, the transport controls) does NOT
    // come from anywhere else; video_player renders to a texture and ships no
    // UI at all.
    //
    // Keep this version in step with video_player_android's `exoplayerVersion`
    // (its android/build.gradle.kts pins it). Gradle resolves the two to the
    // highest of the pair, so a drift makes -ui and -exoplayer straddle a
    // release, which is exactly how you get a NoSuchMethodError at runtime
    // instead of a compile error here.
    val media3Version = "1.9.2"
    implementation("androidx.media3:media3-exoplayer:${media3Version}")
    implementation("androidx.media3:media3-ui:${media3Version}")
}
