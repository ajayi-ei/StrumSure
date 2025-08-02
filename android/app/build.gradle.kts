// android/app/build.gradle.kts

// This file is the Gradle build configuration script for the Android part of your Flutter application.
// It defines how the Android project is built, including dependencies, SDK versions,
// application ID, and build types (e.g., debug, release).

plugins {
    // Apply the Android Application plugin, which provides tasks for building Android apps.
    id("com.android.application")
    // Apply the Kotlin Android plugin, enabling Kotlin language features in the Android project.
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    // This plugin integrates Flutter's build system with the Android Gradle build process.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Defines the namespace for the Android project, which is typically derived from the package name.
    // It helps in resolving resources and avoiding conflicts.
    namespace = "com.bnkmusicmall.strum_sure" // Updated to match the new application branding.

    // Specifies the Android API level used to compile your application.
    // `flutter.compileSdkVersion` is a property provided by the Flutter Gradle plugin,
    // ensuring consistency with the Flutter SDK's requirements.
    compileSdk = flutter.compileSdkVersion

    // Specifies the version of the Android NDK (Native Development Kit) to use.
    // NDK is required for Flutter to compile its C/C++ engine code for Android.
    // `flutter.ndkVersion` would use the version specified by Flutter,
    // but it's explicitly set here to a specific version for consistency.
    ndkVersion = "27.0.12077973" // A specific NDK version is used.

    // Configures Java compatibility options for compilation.
    compileOptions {
        // Sets the Java language level for source code.
        sourceCompatibility = JavaVersion.VERSION_11
        // Sets the Java language level that the compiled bytecode will target.
        targetCompatibility = JavaVersion.VERSION_11
    }

    // Configures Kotlin-specific compilation options.
    kotlinOptions {
        // Sets the JVM target version for Kotlin compilation, ensuring compatibility.
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // Defines default configurations for all build variants (e.g., debug, release).
    defaultConfig {
        // The unique application ID for your Android app. This must be unique across all
        // apps installed on a device and on Google Play.
        applicationId = "com.bnkmusicmall.strum_sure" // Updated to match the new application branding.

        // The minimum Android API level that your application supports.
        // Devices running a lower API level will not be able to install this app.
        // It's explicitly set to 24 (Android 7.0 Nougat).
        minSdk = 24
        // The target Android API level. This indicates that you have tested your app
        // on this version (and higher) and it behaves correctly.
        targetSdk = flutter.targetSdkVersion
        // An integer value that represents the version of the application code.
        // Used for internal version tracking and updates on Google Play.
        versionCode = flutter.versionCode
        // A string value that represents the user-visible version of the application.
        // This is what users see (e.g., "1.0.0").
        versionName = flutter.versionName
    }

    // Configures different build types (e.g., debug, release).
    buildTypes {
        // Configuration for the release build of the application.
        release {
            // Specifies the signing configuration to use for the release build.
            // For production apps, this should point to your own keystore for signing.
            // Currently, it's set to use the debug signing configuration for convenience
            // during development and testing with `flutter run --release`.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Configures the Flutter integration.
flutter {
    // Specifies the path to the root of your Flutter project relative to this build.gradle.kts file.
    // This tells the Flutter Gradle plugin where to find your Flutter source code.
    source = "../.."
}
