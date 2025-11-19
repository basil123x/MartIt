plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mazo.market"
    compileSdk = 36 // Android 15+ for 16KB page size support
    ndkVersion = "27.0.12077973"

    signingConfigs {
        create("release") {
            keyAlias = "globee-keystore"
            keyPassword = "A122%133z."
            storeFile = file("globee.keystore")
            storePassword = "A122%133z."
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.mazo.market"
        minSdk = flutter.minSdkVersion // Minimum SDK for modern Android features
        targetSdk = 35 // Target Android 15+ for 16KB page size support
        multiDexEnabled = true
        versionCode = 4
        versionName = "1.0.0"
        
        // Enable 16KB page size support
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

    buildTypes {
        getByName("release") {
                signingConfig = signingConfigs.getByName("release")
                isMinifyEnabled = false
                isShrinkResources = false
        }
    }
    
    // Enable 16KB page size support
    bundle {
        language {
            enableSplit = false
        }
        density {
            enableSplit = true
        }
        abi {
            enableSplit = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.android.material:material:1.12.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
