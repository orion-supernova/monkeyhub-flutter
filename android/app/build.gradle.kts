plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Reads android/app/google-services.json and exposes FCM credentials at
    // build time. Required by firebase_messaging.
    id("com.google.gms.google-services")
}

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
        versionCode = 137001
        versionName = "1.3.7"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")
}
