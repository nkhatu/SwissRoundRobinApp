// ---------------------------------------------------------------------------
// srr_app/android/settings.gradle.kts
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Defines Gradle project inclusion and plugin management settings.
// Architecture:
// - Platform build configuration file controlling project-level Gradle wiring.
// - Keeps Android project composition explicit and reproducible.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("com.google.gms.google-services") version "4.4.4" apply false
}

include(":app")
