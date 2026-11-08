plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.aaudraa.keykey"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.aaudraa.keykey"
        minSdk = 30
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // R8 kullanılmayan kodu ve kaynakları atar, adları kısaltır. Flutter
            // eklentisi bunu zaten açıyor; burada açıkça yazılı ki kapanırsa
            // fark edilsin. check-release-apk.sh de denetler. Gereken keep
            // kuralları kütüphanelerin kendi kurallarından ve Flutter'dan geliyor.
            isMinifyEnabled = true
            isShrinkResources = true
            // Faz 9'a kadar debug anahtarıyla imzalanır. Yayın anahtarı repoya girmez.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        resources {
            // kotlinx-coroutines'in hata ayıklama aracı dosyası; uygulamada işe yaramaz.
            excludes += "DebugProbesKt.bin"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Kararlı son sürüm; daha yenileri henüz beta.
    implementation("androidx.biometric:biometric:1.1.0")
    // pigeon'un ürettiği köprü coroutine kullanıyor.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    // Otomatik doldurmanın klavye şeridindeki (satır içi) öneri görünümü.
    implementation("androidx.autofill:autofill:1.3.0")

    constraints {
        // CameraX eklentisi 33.5.0'ı getiriyor; GHSA-xxph-c9ww-hj94 33.7.2'de
        // düzeltildi. KeyKey Java serileştirmesi kullanmadığı için açık
        // tetiklenemez, ama düzeltilmiş sürüm kullanılır.
        implementation("com.google.guava:guava:33.8.0-android")
    }

    // Otomatik doldurmanın saf Kotlin kısımları (alan tespiti, eşleştirme) JVM'de sınanır.
    testImplementation("junit:junit:4.13.2")
}

flutter {
    source = "../.."
}
