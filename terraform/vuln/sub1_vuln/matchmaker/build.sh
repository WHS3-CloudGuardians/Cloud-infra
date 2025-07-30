#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="$(dirname "$0")/../build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

pip3 install --upgrade pip --break-system-packages
pip3 install -r "$(dirname "$0")/requirements.txt" -t "$BUILD_DIR" --break-system-packages

cp -r "$(dirname "$0")/src"/*.py "$BUILD_DIR"

pushd "$BUILD_DIR" >/dev/null
zip -r ../matchmaker.zip .
popd >/dev/null

echo "Built matchmaker.zip in ${BUILD_DIR}/.."
