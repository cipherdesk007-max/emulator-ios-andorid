// FMLAB Controller (Android): il telefono Android diventa il Controller 2…4 di FMLAB Emulator sullo stesso Wi-Fi.
import java.io.File

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val versione = File(rootDir, "../VERSIONE").readText().trim()
val numero = (System.getenv("GITHUB_RUN_NUMBER") ?: "1").toInt()

android {
    namespace = "dev.fmlab.controller"
    compileSdk = 35
    defaultConfig {
        applicationId = "dev.fmlab.controller"
        minSdk = 24
        targetSdk = 35
        versionCode = numero
        versionName = versione
    }
    signingConfigs {
        create("fmlab") {
            // firma fissa, così ogni versione si installa sopra la precedente (vedi android/firma/LEGGIMI.md)
            storeFile = file(System.getenv("FMLAB_KEYSTORE") ?: "../firma/fmlab-pubblica.jks")
            storePassword = System.getenv("FMLAB_KEYSTORE_PASSWORD") ?: "fmlab-controller"
            keyAlias = System.getenv("FMLAB_KEY_ALIAS") ?: "fmlab"
            keyPassword = System.getenv("FMLAB_KEYSTORE_PASSWORD") ?: "fmlab-controller"
        }
    }
    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            signingConfig = signingConfigs.getByName("fmlab")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}
