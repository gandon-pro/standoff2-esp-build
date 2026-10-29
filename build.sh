#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
mkdir -p out
xcrun --sdk iphoneos clang++ -std=c++17 -fobjc-arc -dynamiclib \
  -target arm64-apple-ios15.0 -isysroot "$sdk" \
  -framework UIKit -framework QuartzCore -O2 \
  -install_name @rpath/S2ESP.dylib ESP.mm -o out/S2ESP.dylib
xcrun --sdk iphoneos otool -hv out/S2ESP.dylib
