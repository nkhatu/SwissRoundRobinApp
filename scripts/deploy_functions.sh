#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# scripts/deploy_functions.sh
# ---------------------------------------------------------------------------
# 
# Purpose:
# - Deploys Firebase Cloud Functions for SRR backend APIs.
# Architecture:
# - Operational script that scopes and runs backend function deployment commands.
# - Separates function-only release steps from app build workflows.
# Author: Neil Khatu
# Copyright (c) The Khatu Family Trust
# 
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ID="${FIREBASE_PROJECT_ID:-your-firebase-project-id}"
FUNCTIONS_TARGET="${FIREBASE_FUNCTIONS_TARGET:-}"
APP_VERSION="${APP_VERSION:-}"
APP_BUILD_NUMBER="${APP_BUILD_NUMBER:-}"

cd "$ROOT_DIR"

if [[ -n "$FUNCTIONS_TARGET" ]]; then
  DEPLOY_ONLY="functions:$FUNCTIONS_TARGET"
else
  DEPLOY_ONLY="functions"
fi

if [[ "$PROJECT_ID" == "your-firebase-project-id" ]]; then
  echo "Set FIREBASE_PROJECT_ID before running deploy_functions.sh."
  exit 1
fi

if [[ -n "$APP_VERSION" && -n "$APP_BUILD_NUMBER" ]]; then
  echo "Deploying functions for app release: $APP_VERSION+$APP_BUILD_NUMBER"
fi

firebase deploy --only "$DEPLOY_ONLY" --project "$PROJECT_ID"

echo "Functions deploy complete."
