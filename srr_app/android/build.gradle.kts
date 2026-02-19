// ---------------------------------------------------------------------------
// srr_app/android/build.gradle.kts
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Defines Gradle build configuration for the Android project/module.
// Architecture:
// - Platform build configuration layer for plugin, dependency, and compile settings.
// - Separates Android build concerns from shared Flutter application logic.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
