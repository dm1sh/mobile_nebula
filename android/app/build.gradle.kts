import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "net.defined.mobile_nebula"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "net.defined.mobile_nebula"
        minSdk = 25
        targetSdk = flutter.targetSdkVersion //TODO: was hardcoded to 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = System.getenv("RELEASE_KEY_ALIAS") ?: "key"
            storeFile = System.getenv("RELEASE_KEYSTORE_PATH")?.let { file(it) }
            storePassword = System.getenv("RELEASE_KEYSTORE_PASSWORD")
            // Fall back to storePassword if no separate key password is set
            keyPassword = System.getenv("RELEASE_KEY_PASSWORD") ?: System.getenv("RELEASE_KEYSTORE_PASSWORD")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = if (signingConfigs.getByName("release").storeFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            resValue("string", "app_name", "\"Nebula\"")
        }

        debug {
            resValue("string", "app_name", "\"Nebula-DEBUG\"")
            applicationIdSuffix = ".debug"
        }

        // x86 has no AOT engine, so the distributable x86 APK is a JIT (profile) build.
        // Sign it with the release keystore and use the plain package id/app name.
        profile {
            signingConfig = if (signingConfigs.getByName("release").storeFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            applicationIdSuffix = null
            resValue("string", "app_name", "\"Nebula\"")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    var workVersion = "2.11.1"
    implementation("androidx.security:security-crypto:1.1.0")
    implementation("androidx.work:work-runtime-ktx:$workVersion")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("com.google.code.gson:gson:2.13.2")
    implementation("com.google.guava:guava:33.5.0-android")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation(project(":mobileNebula"))

}

