// ---------------------------------------------------------------------------
// srr_app/ios/Runner/AppDelegate.swift
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Defines iOS app delegate lifecycle hooks and Flutter plugin registration.
// Architecture:
// - Platform integration class bridging iOS app lifecycle with Flutter runtime.
// - Keeps platform startup concerns separate from shared Dart modules.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
