plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.zen.zen_app"
    // ZEN_SPEC.md §11.2 fixes the three API levels. They are written out here
    // rather than taken from `flutter.compileSdkVersion` and friends so that a
    // Flutter SDK upgrade cannot move them silently: at the time of writing the
    // SDK's own defaults are 36 / 36 / 24, so minSdk in particular would drift
    // away from the specified 26. See DECISIONS.md, D-M4-2.
    compileSdk = 36
    // Pinned for the same reason as the three levels above, and with sharper
    // teeth: a Flutter SDK upgrade moving `flutter.ndkVersion` makes Gradle try
    // to download the new one, and on this toolchain that download is broken —
    // cmdline-tools 23.0 deprecated `sdkmanager`, and its shim crashes
    // (0xC0000409) rather than failing cleanly, so the build dies with
    // "Package ndk not found" and nothing that names the real cause. This is
    // the version M4 was actually built and verified with. See DECISIONS.md,
    // D-M4-16.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.zen.zen_app"
        // §11.2. Android 8.0. See the compileSdk comment above.
        minSdk = 26
        // §11.9: Play Store distribution is out of scope, so Play's target-API
        // deadlines do not bind, but 36 is still the right setting for device
        // compatibility.
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // §11.9 signs the release APK with a local keystore, which M8 adds
            // along with the tagged-release workflow. Until then the debug keys
            // keep `flutter run --release` working. An APK signed with these is
            // not the release artifact and must not be distributed.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
