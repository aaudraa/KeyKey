// Dokunma korsanlığı ve erişilebilirlik testleri için saldırgan uygulama.
// KeyKey'in parçası değildir. Derleme:
// android/gradlew -p resources/test-apps/saldirgan assembleDebug
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
rootProject.name = "saldirgan"
