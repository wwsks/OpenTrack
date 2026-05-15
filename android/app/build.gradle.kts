plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.opentrack.opentrack"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.opentrack.opentrack"
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            val keystorePropsFile = rootProject.projectDir.resolve("../keystore.properties")
            val keystoreProps = mutableMapOf<String, String>()
            keystorePropsFile.forEachLine { line ->
                val parts = line.split("=", limit = 2)
                if (parts.size == 2) {
                    keystoreProps[parts[0].trim()] = parts[1].trim()
                }
            }
            storeFile = file(keystoreProps["storeFile"]!!)
            storePassword = keystoreProps["storePassword"]!!
            keyAlias = keystoreProps["keyAlias"]!!
            keyPassword = keystoreProps["keyPassword"]!!
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
