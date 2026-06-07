import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // must be last
}

android {
    namespace = "com.example.flutter_application_1"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.flutter_application_1"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false          // No code shrinking
            isShrinkResources = false        // Prevent the "shrinkResources" error
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // Optional: debug config
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    packaging {
        jniLibs {
            excludes += "**/libVkLayer_khronos_validation.so"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Workaround: proactively delete locked Vulkan validation native lib before merge
gradle.projectsEvaluated {
    tasks.matching { it.name.contains("merge") && it.name.contains("NativeLibs") }.configureEach {
        doFirst {
            val abis = listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
            val mergedLibsDir = project.layout.buildDirectory.dir("intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib").get().asFile
            abis.forEach { abi ->
                val target = File(mergedLibsDir, "$abi/libVkLayer_khronos_validation.so")
                if (target.exists()) {
                    logger.lifecycle("Removing locked file to avoid Windows file-lock: ${'$'}{target.absolutePath}")
                    try {
                        target.delete()
                    } catch (e: Exception) {
                        logger.warn("Failed to delete locked file: ${'$'}{e.message}")
                    }
                }
            }
        }
    }
}