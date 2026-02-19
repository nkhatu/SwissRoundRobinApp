// ---------------------------------------------------------------------------
// srr_app/android/app/src/main/kotlin/com/example/carrom_srr/MainActivity.kt
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Defines Android entry activity that hosts the Flutter runtime surface.
// Architecture:
// - Platform integration class bridging Android activity lifecycle with Flutter engine.
// - Keeps platform bootstrap separate from shared Dart feature code.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
package com.example.carrom_srr

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "srr/config",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "googleServerClientId" -> {
                    val resourceId = applicationContext.resources.getIdentifier(
                        "default_web_client_id",
                        "string",
                        applicationContext.packageName,
                    )
                    if (resourceId == 0) {
                        result.success(null)
                    } else {
                        result.success(applicationContext.getString(resourceId))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
