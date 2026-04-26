buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // Настройка Java 11 и Kotlin 11 для всех подпроектов
    afterEvaluate {
        if (project.hasProperty("android")) {
            try {
                val androidExtension = project.extensions.getByName("android")
                if (androidExtension is com.android.build.gradle.BaseExtension) {
                    androidExtension.compileOptions {
                        sourceCompatibility = JavaVersion.VERSION_11
                        targetCompatibility = JavaVersion.VERSION_11
                    }
                }
            } catch (e: Exception) {
                // Игнорируем ошибки для проектов без Android конфигурации
            }
        }
        
        // Настройка Kotlin для всех подпроектов через tasks
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "11"
            }
        }
        
        // Подавление предупреждений об устаревших опциях Java для всех подпроектов
        tasks.withType<JavaCompile>().configureEach {
            options.compilerArgs.addAll(listOf(
                "-Xlint:-options",      // Подавить предупреждения об устаревших опциях
                "-Xlint:-deprecation",  // Подавить предупреждения об устаревших API
                "-Xlint:-unchecked"      // Подавить предупреждения о непроверенных операциях
            ))
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
