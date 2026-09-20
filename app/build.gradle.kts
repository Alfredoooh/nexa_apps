plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.vibely.music.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.vibely.music.app"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"

        // Só arm64-v8a: reduz bastante o peso dos binários nativos do yt-dlp/ffmpeg.
        // A esmagadora maioria dos aparelhos com Android 7+ (minSdk 24) já é 64-bit.
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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

    // Obrigatório para o youtubedl-android: os binários nativos (Python, ffmpeg)
    // precisam ser extraídos no disco, senão o yt-dlp não consegue executá-los
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.github.TeamNewPipe:NewPipeExtractor:v0.24.4")
    implementation("org.nanohttpd:nanohttpd:2.3.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.3")

    // yt-dlp embutido (Python + yt-dlp + ffmpeg dentro do APK) — só para extração de áudio
    implementation("io.github.junkfood02.youtubedl-android:library:0.17.2")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.17.2")
}