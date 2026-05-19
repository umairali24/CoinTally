import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun signingValue(propertyName: String, environmentName: String): String? {
    return (keystoreProperties[propertyName] as String?) ?: System.getenv(environmentName)
}

val releaseStoreFilePath = signingValue("storeFile", "COINTALLY_STORE_FILE")
    ?: "../cointally-release-key.jks"
val releaseStorePassword = signingValue("storePassword", "COINTALLY_STORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "COINTALLY_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "COINTALLY_KEY_PASSWORD")
val releaseStoreFile = rootProject.file(releaseStoreFilePath)
val releaseSigningConfigured = releaseStoreFile.exists() &&
    !releaseStorePassword.isNullOrBlank() &&
    !releaseKeyAlias.isNullOrBlank() &&
    !releaseKeyPassword.isNullOrBlank()

gradle.taskGraph.whenReady {
    val requestedReleaseBuild = allTasks.any { task ->
        task.name.contains("Release", ignoreCase = true)
    }
    if (requestedReleaseBuild && !releaseSigningConfigured) {
        throw GradleException(
            "Release signing requires android/key.properties or COINTALLY_* environment variables. " +
                "Expected keystore at ${releaseStoreFile.path}."
        )
    }
}

android {
    namespace = "com.cointally.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.cointally.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseSigningConfigured) {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}
