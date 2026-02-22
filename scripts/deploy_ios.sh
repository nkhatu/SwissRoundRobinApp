#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# scripts/deploy_ios.sh
# ---------------------------------------------------------------------------
# 
# Purpose:
# - Builds and deploys the iOS release artifact for Carrom SRR.
# Architecture:
# - Operational script orchestrating iOS release environment setup and build/deploy commands.
# - Keeps iOS release parameters centralized for consistent execution.
# Author: Neil Khatu
# Copyright (c) The Khatu Family Trust
# 
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/srr_app"

IOS_TARGET="${IOS_TARGET:-device}" # device | ipa | run
IOS_BUILD_MODE="${IOS_BUILD_MODE:-release}" # debug | profile | release
IOS_CODESIGN="${IOS_CODESIGN:-1}" # 1 to sign, 0 to disable signing
IOS_DEVICE_ID="${IOS_DEVICE_ID:-}"
IOS_EXPORT_OPTIONS_PLIST="${IOS_EXPORT_OPTIONS_PLIST:-}"
SRR_API_URL="${SRR_API_URL:-https://example.com/api}"
SRR_SUPPORT_EMAIL="${SRR_SUPPORT_EMAIL:-support@example.com}"
SRR_PUBLIC_DOMAIN="${SRR_PUBLIC_DOMAIN:-example.com}"
APP_VERSION="${APP_VERSION:-}"
APP_BUILD_NUMBER="${APP_BUILD_NUMBER:-}"

GOOGLE_WEB_CLIENT_ID="${GOOGLE_WEB_CLIENT_ID:-}"
GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID:-}"
APPLE_CLIENT_ID="${APPLE_CLIENT_ID:-}"
APPLE_REDIRECT_URI="${APPLE_REDIRECT_URI:-https://example.com/api/callbacks/sign_in_with_apple}"

case "$IOS_TARGET" in
  device|ipa|run) ;;
  *)
    echo "Invalid IOS_TARGET: $IOS_TARGET (use: device|ipa|run)"
    exit 1
    ;;
esac

case "$IOS_BUILD_MODE" in
  debug|profile|release) ;;
  *)
    echo "Invalid IOS_BUILD_MODE: $IOS_BUILD_MODE (use: debug|profile|release)"
    exit 1
    ;;
esac

if [[ -n "$APP_VERSION" && ! "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid APP_VERSION: $APP_VERSION (expected x.y.z)"
  exit 1
fi
if [[ -n "$APP_BUILD_NUMBER" && ! "$APP_BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Invalid APP_BUILD_NUMBER: $APP_BUILD_NUMBER (expected integer)"
  exit 1
fi

if [[ "$IOS_TARGET" == "ipa" && "$IOS_BUILD_MODE" == "debug" ]]; then
  echo "IOS_TARGET=ipa does not support debug builds. Use IOS_BUILD_MODE=profile or release."
  exit 1
fi

if [[ "$SRR_SUPPORT_EMAIL" == "support@example.com" ]] ||
   [[ "$SRR_PUBLIC_DOMAIN" == "example.com" ]]; then
  echo "Set SRR_SUPPORT_EMAIL and SRR_PUBLIC_DOMAIN before running deploy_ios.sh."
  exit 1
fi

cd "$APP_DIR"
flutter pub get

define_args=(
  "--dart-define=SRR_API_URL=$SRR_API_URL"
  "--dart-define=SRR_SUPPORT_EMAIL=$SRR_SUPPORT_EMAIL"
  "--dart-define=SRR_PUBLIC_DOMAIN=$SRR_PUBLIC_DOMAIN"
)

version_args=()
if [[ -n "$APP_VERSION" ]]; then
  version_args+=("--build-name=$APP_VERSION")
fi
if [[ -n "$APP_BUILD_NUMBER" ]]; then
  version_args+=("--build-number=$APP_BUILD_NUMBER")
fi

if [[ -n "$GOOGLE_WEB_CLIENT_ID" ]]; then
  define_args+=("--dart-define=GOOGLE_WEB_CLIENT_ID=$GOOGLE_WEB_CLIENT_ID")
fi
if [[ -n "$GOOGLE_SERVER_CLIENT_ID" ]]; then
  define_args+=("--dart-define=GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID")
fi
if [[ -n "$APPLE_CLIENT_ID" ]]; then
  define_args+=("--dart-define=APPLE_CLIENT_ID=$APPLE_CLIENT_ID")
fi
if [[ -n "$APPLE_REDIRECT_URI" ]]; then
  define_args+=("--dart-define=APPLE_REDIRECT_URI=$APPLE_REDIRECT_URI")
fi

if [[ "$IOS_TARGET" == "run" ]]; then
  run_device="${IOS_DEVICE_ID:-ios}"
  flutter run -d "$run_device" "--$IOS_BUILD_MODE" "${version_args[@]}" "${define_args[@]}"
  if [[ -n "$APP_VERSION" || -n "$APP_BUILD_NUMBER" ]]; then
    echo "Ran iOS build version: ${APP_VERSION:-from-pubspec}+${APP_BUILD_NUMBER:-from-pubspec}"
  fi
  echo "iOS deploy complete via flutter run."
  exit 0
fi

build_args=(
  "--$IOS_BUILD_MODE"
  "${version_args[@]}"
  "${define_args[@]}"
)

if [[ "$IOS_TARGET" == "device" ]]; then
  if [[ "$IOS_CODESIGN" != "1" ]]; then
    build_args+=("--no-codesign")
  fi
  flutter build ios "${build_args[@]}"
  if [[ -n "$APP_VERSION" || -n "$APP_BUILD_NUMBER" ]]; then
    echo "Built iOS device version: ${APP_VERSION:-from-pubspec}+${APP_BUILD_NUMBER:-from-pubspec}"
  fi
  echo "iOS device build complete. Install from Xcode or run with IOS_TARGET=run."
  exit 0
fi

# IOS_TARGET=ipa
if [[ "$IOS_CODESIGN" != "1" ]]; then
  build_args+=("--no-codesign")
fi
if [[ -n "$IOS_EXPORT_OPTIONS_PLIST" ]]; then
  build_args+=("--export-options-plist=$IOS_EXPORT_OPTIONS_PLIST")
fi
flutter build ipa "${build_args[@]}"
if [[ -n "$APP_VERSION" || -n "$APP_BUILD_NUMBER" ]]; then
  echo "Built iOS IPA version: ${APP_VERSION:-from-pubspec}+${APP_BUILD_NUMBER:-from-pubspec}"
fi
echo "iOS IPA build complete."
