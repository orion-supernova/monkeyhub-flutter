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
// on machines without the key. deploy.sh refuses to ship a debug-signed APK.
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
        targetSdk = 34
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
}
