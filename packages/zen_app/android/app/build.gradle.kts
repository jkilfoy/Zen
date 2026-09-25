import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ZEN_SPEC.md 11.9. The release signing material, read from
// `android/key.properties`, which is gitignored and must never be committed.
// Absent is the normal case on any machine but the owner's -- a fresh clone, or
// a CI runner -- and is only an error when a release build is actually
// attempted. The task-graph check below is what draws that line.
// See DECISIONS.md, D-M8-3.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

// ZEN_SPEC.md 11.9: "the release build MUST FAIL rather than fall back to the
// debug keystore when the keystore is absent."
//
// The check hangs off the task graph rather than sitting in `buildTypes.release`,
// because that block is configured on every Gradle invocation -- throwing there
// would break `flutter build apk --debug` and `flutter test` on a machine with
// no keystore, which is every machine but the owner's. This fires only when a
// release packaging task is genuinely in the graph. See DECISIONS.md, D-M8-3.
if (!hasReleaseKeystore) {
    gradle.taskGraph.whenReady {
        val wantsRelease = allTasks.any { task ->
            task.name.contains("Release") &&
                (task.name.startsWith("assemble") ||
                    task.name.startsWith("bundle") ||
                    task.name.startsWith("package"))
        }
        if (wantsRelease) {
            throw GradleException(
                "Cannot build a release artifact: packages/zen_app/android/key.properties " +
                    "does not exist, so there is no signing keystore (ZEN_SPEC.md 11.9).\n\n" +
                    "Falling back to the debug keystore is deliberately NOT done. A " +
                    "debug-signed APK installs cleanly on this machine's own device, " +
                    "because the debug key is already trusted there -- and can then never " +
                    "be upgraded by a properly signed one without an uninstall, which " +
                    "destroys the local database.\n\n" +
                    "See MANUAL_VERIFICATION.md, section 'M8 -- the keystore', for how to " +
                    "create it. For a throwaway local build, use --debug or --profile.",
            )
        }
    }
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

    signingConfigs {
        // Registered only when the keystore is present, so that configuring
        // this file needs no keystore. When it is absent the task-graph check
        // above has already failed any release build, and `buildTypes` below
        // leaves `signingConfig` unset.
        if (hasReleaseKeystore) {
            create("release") {
                val storePath = keystoreProperties.getProperty("storeFile")
                    ?: error("key.properties is missing `storeFile`.")
                storeFile = rootProject.file(storePath)
                storePassword = keystoreProperties.getProperty("storePassword")
                    ?: error("key.properties is missing `storePassword`.")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                    ?: error("key.properties is missing `keyAlias`.")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                    ?: error("key.properties is missing `keyPassword`.")
                require(storeFile!!.exists()) {
                    "key.properties points at ${storeFile!!.absolutePath}, " +
                        "which does not exist."
                }
            }
        }
    }

    buildTypes {
        release {
            // Signed with the local keystore (ZEN_SPEC.md 11.9). This used to
            // read `signingConfigs.getByName("debug")`, which was correct while
            // M8 was unbuilt and is dangerous now -- see the task-graph check
            // above for why there is no fallback. When the keystore is absent
            // this is left unset and that check has already failed the build.
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
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
