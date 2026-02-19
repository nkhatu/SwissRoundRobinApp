#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# scripts/commit_remote_obfuscated.sh
# ---------------------------------------------------------------------------
#
# Purpose:
# - Applies a pre-push obfuscation pass for known project-specific identifiers.
# - Verifies no blocked sensitive patterns remain, then commits and pushes.
# Architecture:
# - Operational release-safety script that combines sanitize, verify, and git push steps.
# - Keeps public-repo hygiene logic centralized and repeatable from one command.
# Author: Neil Khatu
# Copyright (c) The Khatu Family Trust
#
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REMOTE="${GIT_REMOTE:-origin}"
BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
COMMIT_MESSAGE=""
PUSH_ENABLED=1
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  scripts/commit_remote_obfuscated.sh -m "commit message" [options]

Options:
  -m, --message <text>   Commit message (required)
  -r, --remote <name>    Git remote (default: origin)
  -b, --branch <name>    Git branch (default: current branch)
      --no-push          Commit locally only
      --dry-run          Run obfuscation and checks, skip commit/push
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--message)
      COMMIT_MESSAGE="${2:-}"
      shift 2
      ;;
    -r|--remote)
      REMOTE="${2:-}"
      shift 2
      ;;
    -b|--branch)
      BRANCH="${2:-}"
      shift 2
      ;;
    --no-push)
      PUSH_ENABLED=0
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$COMMIT_MESSAGE" && "$DRY_RUN" -ne 1 ]]; then
  echo "Commit message is required."
  usage
  exit 1
fi

if command -v rg >/dev/null 2>&1; then
  SEARCH_TOOL="rg"
elif command -v grep >/dev/null 2>&1; then
  SEARCH_TOOL="grep"
else
  echo "Neither 'rg' nor 'grep' is available. Install one and retry."
  exit 1
fi

TEXT_FILE_REGEX='(\.(md|txt|json|ya?ml|toml|sh|bash|zsh|dart|ts|tsx|js|jsx|py|kt|kts|swift|java|xml|plist|pbxproj|csv|env|properties|example)$|(^|/)\.env(\..+)?$)'

text_files=()
while IFS= read -r path; do
  [[ -f "$path" ]] || continue
  text_files+=("$path")
done < <(
  if [[ "$SEARCH_TOOL" == "rg" ]]; then
    git ls-files | rg -N "$TEXT_FILE_REGEX" || true
  else
    git ls-files | grep -E "$TEXT_FILE_REGEX" || true
  fi
)

if [[ ${#text_files[@]} -gt 0 ]]; then
  perl -pi -e '
    s/\bcarrom\.khatu\.com\b/example.com/g;
    s/\bkhatu\.com\b/example.com/g;
    s/\bsrr\.khatu\.com\b/srr.example.com/g;
    s/\bsupport\@khatu\.com\b/support@example.com/g;
    s/\bcarrom-srr\b/your-firebase-project-id/g;
    s/\bcom\.khatu\.carrom_srr\b/com.example.carrom_srr/g;
    s/\bcom\.khatu\.your-firebase-project-id\b/com.example.your-firebase-project-id/g;
    s/\bcom\.khatu\.carrom\b/com.example.carrom/g;
    s/\bAIza[0-9A-Za-z_-]{35}\b/YOUR_FIREBASE_WEB_API_KEY/g;
    s/\b\d+-[0-9A-Za-z_-]+\.apps\.googleusercontent\.com\b/YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com/g;
    s/\b1:\d+:web:[0-9a-f]+\b/YOUR_FIREBASE_WEB_APP_ID/g;
  ' "${text_files[@]}"
fi

blocklist_regex='khatu\.com|carrom\.khatu\.com|support@khatu\.com|srr\.khatu\.com|com\.khatu\.|AIza[0-9A-Za-z_-]{35}|\b\d+-[0-9A-Za-z_-]+\.apps\.googleusercontent\.com\b'

scan_files=()
while IFS= read -r path; do
  [[ -f "$path" ]] || continue
  case "$path" in
    */build/*|*/.dart_tool/*|*/node_modules/*) continue ;;
  esac
  scan_files+=("$path")
done < <(git ls-files)

if [[ "$SEARCH_TOOL" == "rg" ]]; then
  if rg -n "$blocklist_regex" "${scan_files[@]}" >/tmp/obfuscation_violations.txt; then
    echo "Blocked patterns still found after obfuscation:"
    cat /tmp/obfuscation_violations.txt
    exit 1
  fi
elif [[ "${#scan_files[@]}" -gt 0 ]] &&
     grep -nE "$blocklist_regex" "${scan_files[@]}" >/tmp/obfuscation_violations.txt; then
  echo "Blocked patterns still found after obfuscation:"
  cat /tmp/obfuscation_violations.txt
  exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run complete: obfuscation and blocklist checks passed."
  exit 0
fi

git add -A

if git diff --cached --quiet; then
  echo "No changes to commit."
  exit 0
fi

git commit -m "$COMMIT_MESSAGE"

if [[ "$PUSH_ENABLED" -eq 1 ]]; then
  git push "$REMOTE" "$BRANCH"
  echo "Pushed to $REMOTE/$BRANCH with obfuscation checks."
else
  echo "Committed locally (push skipped)."
fi
