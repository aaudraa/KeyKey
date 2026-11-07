plugins {
    id("com.android.application") version "9.5.0"
}

android {
    namespace = "io.github.aaudraa.ornekgiris"
    compileSdk = 36

    defaultConfig {
        // Saldırı testi aynı paket adını farklı anahtarla imzalar:
        // -PornekImza=<keystore yolu> verilirse o anahtar kullanılır.
        applicationId = "io.github.aaudraa.ornekgiris"
        minSdk = 30
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    val imza = providers.gradleProperty("ornekImza").orNull
    if (imza != null) {
        signingConfigs {
            create("sahte") {
                storeFile = file(imza)
                storePassword = "sahte-anahtar"
                keyAlias = "sahte"
                keyPassword = "sahte-anahtar"
            }
        }
        buildTypes.getByName("debug").signingConfig = signingConfigs.getByName("sahte")
    }
}
