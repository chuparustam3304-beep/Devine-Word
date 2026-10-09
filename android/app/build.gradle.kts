import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningPropertiesFile = rootProject.file("key.properties")
val releaseSigningProperties = Properties()
if (releaseSigningPropertiesFile.exists()) {
    releaseSigningPropertiesFile.inputStream().use(releaseSigningProperties::load)
}

val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.endsWith("Release", ignoreCase = true)
}
if (releaseBuildRequested && !releaseSigningPropertiesFile.exists()) {
    throw GradleException(
        "Android release signing is not configured. Create android/key.properties " +
            "from android/key.properties.example and provide your private upload keystore."
    )
}

android {
    namespace = "com.devine.devine_word"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        // flutter_local_notifications: scheduled notifications require
        // core library desugaring on older Android versions.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.devine.devine_word"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseSigningPropertiesFile.exists()) {
                keyAlias = releaseSigningProperties.getProperty("keyAlias")
                    ?: throw GradleException("keyAlias is missing from android/key.properties")
                keyPassword = releaseSigningProperties.getProperty("keyPassword")
                    ?: throw GradleException("keyPassword is missing from android/key.properties")
                storeFile = rootProject.file(
                    releaseSigningProperties.getProperty("storeFile")
                        ?: throw GradleException("storeFile is missing from android/key.properties")
                )
                storePassword = releaseSigningProperties.getProperty("storePassword")
                    ?: throw GradleException("storePassword is missing from android/key.properties")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by flutter_local_notifications for scheduled notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
