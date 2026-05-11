#!/usr/bin/env bash
# Build SPM executable and package into ClaudeHelper.app bundle.
# Usage: ./scripts/build-app.sh [debug|release]

set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="ClaudeHelper"
BUNDLE_ID="io.pegues.ClaudeHelper"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT}/.build"
APP_BUNDLE="${ROOT}/dist/${APP_NAME}.app"

echo "==> Building ${APP_NAME} (${CONFIG})"
cd "${ROOT}"

# Universal binary for distribution; arm64 for local dev
if [[ "${CONFIG}" == "release" ]]; then
  swift build -c release --arch arm64 --arch x86_64
  BIN_PATH="${BUILD_DIR}/apple/Products/Release/${APP_NAME}"
else
  swift build -c debug
  BIN_PATH="${BUILD_DIR}/debug/${APP_NAME}"
fi

echo "==> Assembling .app bundle at ${APP_BUNDLE}"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${ROOT}/Sources/ClaudeHelper/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# Copy bundled resources if any (Assets.car etc.)
if [[ -d "${BUILD_DIR}/release/${APP_NAME}_ClaudeHelper.bundle" ]]; then
  cp -R "${BUILD_DIR}/release/${APP_NAME}_ClaudeHelper.bundle" "${APP_BUNDLE}/Contents/Resources/"
fi

echo "==> Codesigning (ad-hoc)"
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> Built: ${APP_BUNDLE}"
echo "==> Run with: open ${APP_BUNDLE}"
