import java.util.Properties
import java.io.FileInputStream
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.ssboss.ssbossmp"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion = flutter.ndkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ssboss.ssbossmp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Читаем key.properties для подписи release версии
            val keystorePropertiesFile = rootProject.file("key.properties")
            val keystoreProperties = Properties()
            if (keystorePropertiesFile.exists()) {
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))
                val storeFileStr = keystoreProperties["storeFile"] as String?
                // Проверяем, что путь к keystore указан и файл существует
                if (storeFileStr != null && storeFileStr.isNotEmpty() && !storeFileStr.contains("ВашеИмя")) {
                    // Если путь относительный, ищем относительно корня проекта (android/)
                    // Если абсолютный, используем как есть
                    val keystoreFile = if (File(storeFileStr).isAbsolute) {
                        file(storeFileStr)
                    } else {
                        // Относительный путь - ищем относительно корня проекта android
                        rootProject.file(storeFileStr)
                    }
                    if (keystoreFile.exists()) {
                        keyAlias = keystoreProperties["keyAlias"] as String
                        keyPassword = keystoreProperties["keyPassword"] as String
                        storeFile = keystoreFile
                        storePassword = keystoreProperties["storePassword"] as String
                    } else {
                        println("WARNING: Keystore file not found: ${keystoreFile.absolutePath}")
                    }
                }
            }
        }
    }

    buildTypes {
        release {
            // Используем release signing config если key.properties существует
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Fallback на debug signing для разработки
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // enableEdgeToEdge() в MainActivity (Android 15 edge-to-edge, Play Console)
    implementation("androidx.activity:activity-ktx:1.9.3")
}

// Подавление предупреждений об устаревших опциях Java
tasks.withType<JavaCompile>().configureEach {
    options.compilerArgs.addAll(listOf(
        "-Xlint:-options",      // Подавить предупреждения об устаревших опциях
        "-Xlint:-deprecation",  // Подавить предупреждения об устаревших API
        "-Xlint:-unchecked"      // Подавить предупреждения о непроверенных операциях
    ))
}

// Настройка Kotlin JVM target для всех задач компиляции Kotlin
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    kotlinOptions {
        jvmTarget = "11"
    }
}

flutter {
    source = "../.."
}

// Задача для ручного удаления старой версии перед установкой
// Это помогает избежать ошибки INSTALL_FAILED_INSUFFICIENT_STORAGE
// Использование: ./gradlew uninstallOldVersion
// Примечание: Flutter автоматически удаляет старую версию при установке,
// но эта задача может быть полезна для ручной очистки
tasks.register("uninstallOldVersion") {
    doLast {
        try {
            exec {
                commandLine("adb", "uninstall", "com.ssboss.ssbossmp")
                isIgnoreExitValue = true // Игнорируем ошибки, если приложение не установлено
            }
            println("Старая версия приложения успешно удалена")
        } catch (e: Exception) {
            // Игнорируем ошибки, если приложение не установлено или ADB недоступен
            println("Не удалось удалить старую версию (это нормально, если приложение не установлено): ${e.message}")
        }
    }
}
