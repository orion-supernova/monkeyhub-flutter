plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Note: Android applicationId disallows '-' in package segments,
    // so we drop the hyphen from v02's iOS bundle id (com.walhallaa.chatTest-20241220)
    // while keeping the same vendor namespace.
    namespace = "com.walhallaa.chattest20241220"
    compileSdk = 34
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
        minSdk = 23
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
