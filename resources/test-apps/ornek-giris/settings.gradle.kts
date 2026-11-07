// Otomatik doldurma testleri için örnek giriş uygulaması. KeyKey'in parçası değildir.
// Derleme: android/gradlew -p resources/test-apps/ornek-giris assembleDebug
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "ornek-giris"
