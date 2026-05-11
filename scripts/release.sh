#!/usr/bin/env bash
# Cut a release: build, package, tag, push, create GitHub release with .app artifact.
# Usage: ./scripts/release.sh v0.1.0

set -euo pipefail

VERSION="${1:?usage: ./scripts/release.sh v0.1.0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${ROOT}/dist/ClaudeHelper.app"
ZIP_PATH="${ROOT}/dist/ClaudeHelper-${VERSION}.zip"

cd "${ROOT}"

echo "==> Building release"
./scripts/build-app.sh release

echo "==> Zipping bundle"
( cd "$(dirname "${APP_BUNDLE}")" && zip -qr "${ZIP_PATH}" "$(basename "${APP_BUNDLE}")" )

echo "==> Tagging ${VERSION}"
git tag -a "${VERSION}" -m "Release ${VERSION}"
git push origin "${VERSION}"

echo "==> Creating GitHub release"
gh release create "${VERSION}" \
  --title "Claude Helper ${VERSION}" \
  --notes-file CHANGELOG.md \
  "${ZIP_PATH}"

echo "==> Released ${VERSION}"
