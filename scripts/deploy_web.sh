#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# scripts/deploy_web.sh
# ---------------------------------------------------------------------------
# 
# Purpose:
# - Builds and deploys the web app to Firebase Hosting targets.
# Architecture:
# - Operational script wrapping Flutter web build and Firebase deploy commands.
# - Centralizes release-time configuration for predictable web deployments.
# Author: Neil Khatu
# Copyright (c) The Khatu Family Trust
# 
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/srr_app"

PROJECT_ID="${FIREBASE_PROJECT_ID:-your-firebase-project-id}"
DEPLOY_ONLY="${FIREBASE_DEPLOY_ONLY:-hosting}"
WEB_BUILD_MODE="${WEB_BUILD_MODE:-release}"
SRR_API_URL="${SRR_API_URL:-https://example.com/api}"
SRR_SUPPORT_EMAIL="${SRR_SUPPORT_EMAIL:-support@example.com}"
SRR_PUBLIC_DOMAIN="${SRR_PUBLIC_DOMAIN:-example.com}"

# Set these env vars from your Firebase web app config.
FIREBASE_WEB_API_KEY="${FIREBASE_WEB_API_KEY:-YOUR_FIREBASE_WEB_API_KEY}"
FIREBASE_WEB_APP_ID="${FIREBASE_WEB_APP_ID:-YOUR_FIREBASE_WEB_APP_ID}"
FIREBASE_WEB_MESSAGING_SENDER_ID="${FIREBASE_WEB_MESSAGING_SENDER_ID:-YOUR_FIREBASE_WEB_MESSAGING_SENDER_ID}"
FIREBASE_WEB_PROJECT_ID="${FIREBASE_WEB_PROJECT_ID:-$PROJECT_ID}"
FIREBASE_WEB_AUTH_DOMAIN="${FIREBASE_WEB_AUTH_DOMAIN:-${FIREBASE_WEB_PROJECT_ID}.firebaseapp.com}"
FIREBASE_WEB_STORAGE_BUCKET="${FIREBASE_WEB_STORAGE_BUCKET:-${FIREBASE_WEB_PROJECT_ID}.firebasestorage.app}"
FIREBASE_WEB_MEASUREMENT_ID="${FIREBASE_WEB_MEASUREMENT_ID:-}"

if [[ "$PROJECT_ID" == "your-firebase-project-id" ]]; then
  echo "Set FIREBASE_PROJECT_ID before running deploy_web.sh."
  exit 1
fi

if [[ "$FIREBASE_WEB_API_KEY" == "YOUR_FIREBASE_WEB_API_KEY" ]] ||
   [[ "$FIREBASE_WEB_APP_ID" == "YOUR_FIREBASE_WEB_APP_ID" ]] ||
   [[ "$FIREBASE_WEB_MESSAGING_SENDER_ID" == "YOUR_FIREBASE_WEB_MESSAGING_SENDER_ID" ]]; then
  echo "Set FIREBASE_WEB_API_KEY, FIREBASE_WEB_APP_ID, and FIREBASE_WEB_MESSAGING_SENDER_ID before running deploy_web.sh."
  exit 1
fi

if [[ "$SRR_SUPPORT_EMAIL" == "support@example.com" ]] ||
   [[ "$SRR_PUBLIC_DOMAIN" == "example.com" ]]; then
  echo "Set SRR_SUPPORT_EMAIL and SRR_PUBLIC_DOMAIN before running deploy_web.sh."
  exit 1
fi

case "$WEB_BUILD_MODE" in
  debug|profile|release) ;;
  *)
    echo "Invalid WEB_BUILD_MODE: $WEB_BUILD_MODE (use: debug|profile|release)"
    exit 1
    ;;
esac

cd "$APP_DIR"
flutter pub get

flutter build web \
  "--$WEB_BUILD_MODE" \
  --dart-define="SRR_API_URL=$SRR_API_URL" \
  --dart-define="SRR_SUPPORT_EMAIL=$SRR_SUPPORT_EMAIL" \
  --dart-define="SRR_PUBLIC_DOMAIN=$SRR_PUBLIC_DOMAIN" \
  --dart-define="FIREBASE_WEB_API_KEY=$FIREBASE_WEB_API_KEY" \
  --dart-define="FIREBASE_WEB_APP_ID=$FIREBASE_WEB_APP_ID" \
  --dart-define="FIREBASE_WEB_MESSAGING_SENDER_ID=$FIREBASE_WEB_MESSAGING_SENDER_ID" \
  --dart-define="FIREBASE_WEB_PROJECT_ID=$FIREBASE_WEB_PROJECT_ID" \
  --dart-define="FIREBASE_WEB_AUTH_DOMAIN=$FIREBASE_WEB_AUTH_DOMAIN" \
  --dart-define="FIREBASE_WEB_STORAGE_BUCKET=$FIREBASE_WEB_STORAGE_BUCKET" \
  --dart-define="FIREBASE_WEB_MEASUREMENT_ID=$FIREBASE_WEB_MEASUREMENT_ID"

cd "$ROOT_DIR"
firebase deploy --only "$DEPLOY_ONLY" --project "$PROJECT_ID"

echo "Web deploy complete."
