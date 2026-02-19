#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# scripts/deploy_android.sh
# ---------------------------------------------------------------------------
# 
# Purpose:
# - Builds and deploys the Android release artifact for Carrom SRR.
# Architecture:
# - Operational script orchestrating release environment setup and build/deploy commands.
# - Keeps Android release parameters centralized for consistent execution.
# Author: Neil Khatu
# Copyright (c) The Khatu Family Trust
# 
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/srr_app"

ANDROID_BUILD_MODE="${ANDROID_BUILD_MODE:-debug}"
ANDROID_INSTALL="${ANDROID_INSTALL:-1}"
ANDROID_DEVICE_ID="${ANDROID_DEVICE_ID:-}"
SRR_API_URL="${SRR_API_URL:-https://example.com/api}"

GOOGLE_WEB_CLIENT_ID="${GOOGLE_WEB_CLIENT_ID:-}"
GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID:-}"
APPLE_CLIENT_ID="${APPLE_CLIENT_ID:-}"
APPLE_REDIRECT_URI="${APPLE_REDIRECT_URI:-https://example.com/api/callbacks/sign_in_with_apple}"

case "$ANDROID_BUILD_MODE" in
  debug|profile|release) ;;
  *)
    echo "Invalid ANDROID_BUILD_MODE: $ANDROID_BUILD_MODE (use: debug|profile|release)"
    exit 1
    ;;
esac

cd "$APP_DIR"
flutter pub get

build_args=(
  "--$ANDROID_BUILD_MODE"
  "--dart-define=SRR_API_URL=$SRR_API_URL"
)

if [[ -n "$GOOGLE_WEB_CLIENT_ID" ]]; then
  build_args+=("--dart-define=GOOGLE_WEB_CLIENT_ID=$GOOGLE_WEB_CLIENT_ID")
fi
if [[ -n "$GOOGLE_SERVER_CLIENT_ID" ]]; then
  build_args+=("--dart-define=GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID")
fi
if [[ -n "$APPLE_CLIENT_ID" ]]; then
  build_args+=("--dart-define=APPLE_CLIENT_ID=$APPLE_CLIENT_ID")
fi
if [[ -n "$APPLE_REDIRECT_URI" ]]; then
  build_args+=("--dart-define=APPLE_REDIRECT_URI=$APPLE_REDIRECT_URI")
fi

flutter build apk "${build_args[@]}"

case "$ANDROID_BUILD_MODE" in
  debug) APK_PATH="$APP_DIR/build/app/outputs/flutter-apk/app-debug.apk" ;;
  profile) APK_PATH="$APP_DIR/build/app/outputs/flutter-apk/app-profile.apk" ;;
  release) APK_PATH="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk" ;;
esac

if [[ "$ANDROID_INSTALL" != "1" ]]; then
  echo "APK build complete: $APK_PATH"
  exit 0
fi

if ! command -v adb >/dev/null 2>&1; then
  echo "adb not found. Install Android platform-tools or set ANDROID_INSTALL=0."
  exit 1
fi

if [[ -z "$ANDROID_DEVICE_ID" ]]; then
  devices=()
  while IFS= read -r device_id; do
    [[ -n "$device_id" ]] && devices+=("$device_id")
  done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
  if [[ "${#devices[@]}" -eq 0 ]]; then
    echo "No Android device found. Connect a device or set ANDROID_INSTALL=0."
    exit 1
  fi
  if [[ "${#devices[@]}" -gt 1 ]]; then
    echo "Multiple devices found. Set ANDROID_DEVICE_ID to one of:"
    printf '  %s\n' "${devices[@]}"
    exit 1
  fi
  ANDROID_DEVICE_ID="${devices[0]}"
fi

adb -s "$ANDROID_DEVICE_ID" install -r "$APK_PATH"
echo "Android deploy complete on device: $ANDROID_DEVICE_ID"
