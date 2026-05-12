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
mkdir -p "${APP_BUNDLE}/Contents/Frameworks"

cp "${BIN_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${ROOT}/Sources/ClaudeHelper/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# Embed Sparkle.framework so the bundle is self-contained
SPARKLE_SRC=""
for candidate in \
    "${BUILD_DIR}/apple/Products/Release/Sparkle.framework" \
    "${BUILD_DIR}/apple/Products/Debug/Sparkle.framework" \
    "${BUILD_DIR}/release/Sparkle.framework" \
    "${BUILD_DIR}/debug/Sparkle.framework" \
    "${BUILD_DIR}/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
do
  if [[ -d "${candidate}" ]]; then SPARKLE_SRC="${candidate}"; break; fi
done
if [[ -n "${SPARKLE_SRC}" ]]; then
  echo "==> Embedding Sparkle from ${SPARKLE_SRC}"
  cp -R "${SPARKLE_SRC}" "${APP_BUNDLE}/Contents/Frameworks/"
else
  echo "!!  Sparkle.framework not found — bundle will fail to launch on dyld load"
fi

# Copy bundled resources if any (Assets.car etc.)
for bundleDir in "${BUILD_DIR}/release/${APP_NAME}_ClaudeHelper.bundle" "${BUILD_DIR}/apple/Products/Release/${APP_NAME}_ClaudeHelper.bundle"; do
  if [[ -d "${bundleDir}" ]]; then
    cp -R "${bundleDir}" "${APP_BUNDLE}/Contents/Resources/"
    break
  fi
done

echo "==> Patching rpath so the binary finds Contents/Frameworks"
install_name_tool -add_rpath "@executable_path/../Frameworks" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

echo "==> Codesigning (ad-hoc)"
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> Built: ${APP_BUNDLE}"
echo "==> Run with: open ${APP_BUNDLE}"
