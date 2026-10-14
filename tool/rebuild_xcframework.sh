#!/bin/sh
#
# Rebuild the prebuilt Rust XCFrameworks used by the Swift Package Manager
# integration:
#
#   ios/dicom_toolkit/dicom_toolkit.xcframework
#   macos/dicom_toolkit/dicom_toolkit.xcframework
#
# Why prebuilt, and why dynamic:
#   * Swift Package Manager cannot build Rust, so the core has to ship as a
#     binary target — exactly like `web/pkg` ships prebuilt WASM.
#   * The flutter_rust_bridge entry points are resolved *by name at runtime*, so
#     nothing references them at link time. A static library would therefore be
#     dropped by the linker (DEAD_CODE_STRIPPING), leaving the app without an
#     engine. A dynamic library keeps its exported symbols and is embedded in
#     the app bundle, so `DicomToolkit.init()` finds it via the process image.
#
# Re-run this and commit the result whenever `rust/src/**` changes — the same
# rule that applies to `web/pkg`.
#
# Usage:
#   tool/rebuild_xcframework.sh [ios|macos|all]      (default: all)
#
# Requirements: Xcode command line tools, and the Rust targets:
#   rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
#   rustup target add aarch64-apple-darwin x86_64-apple-darwin

set -e

cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd -P)"

LIB_NAME="dicom_toolkit"
BUNDLE_ID="dev.dicomtoolkit.dicom-toolkit"
MIN_IOS="11.0"
VERSION="$(sed -n 's/^version: *//p' pubspec.yaml | head -1)"
[ -n "$VERSION" ] || VERSION="0.0.0"

# The install name is set per platform in build_ios/build_macos; it has to match
# the artifact Xcode embeds, so that dyld resolves it from the app bundle via
# @rpath.

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# Wraps a dylib in a shallow .framework (iOS layout).
make_ios_framework() {
  dylib="$1"
  out="$2"
  mkdir -p "$out"
  cp "$dylib" "$out/$LIB_NAME"
  chmod +w "$out/$LIB_NAME"
  cat > "$out/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>$LIB_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>$LIB_NAME</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleSupportedPlatforms</key><array><string>iPhoneOS</string></array>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>MinimumOSVersion</key><string>$MIN_IOS</string>
</dict>
</plist>
PLIST
}

# macOS has no shallow-framework support — Xcode rejects a framework whose
# Info.plist is not at `Versions/Current/Resources/Info.plist`:
#
#   error: Framework ... contains Info.plist, expected
#   Versions/Current/Resources/Info.plist since the platform does not use
#   shallow bundles
#
# So a macOS framework is necessarily versioned, which means `Versions/Current`
# plus the top-level `Foo` and `Resources` symlinks. `dart pub publish`
# dereferences every symlink in the package, so those reach consumers as
# duplicated real directories and files, Xcode cannot resolve `Versions/Current`,
# and codesign refuses to sign the embedded framework:
#
#   Couldn't resolve framework symlink for '.../Versions/Current'
#   apexo.app: code object is not signed at all
#   In subcomponent: .../Contents/Frameworks/dicom_toolkit.framework
#   Command CodeSign failed with a nonzero exit code
#
# A framework therefore cannot be published intact. macOS ships a plain dylib
# instead: it contains no symlinks, survives publication byte for byte, and
# Xcode embeds and signs it like any other dynamic library. iOS is unaffected —
# its framework is shallow by design.

# `dart pub publish` dereferences symlinks inside the package, so nothing a
# consumer relies on may depend on them. Fail loudly if a slice contains one,
# rather than shipping a framework that only breaks once published.
verify_no_symlinks() {
  if find "$1" -type l | grep -q .; then
    echo "error: $1 contains symlinks, which 'dart pub publish' dereferences." >&2
    echo "       Build artifacts without symlinks instead (see make_ios_framework / build_macos)." >&2
    exit 1
  fi
}

build_ios() {
  echo "== iOS =="
  # iOS frameworks are shallow bundles and survive `dart pub publish` intact.
  export RUSTFLAGS="-C link-arg=-Wl,-install_name,@rpath/$LIB_NAME.framework/$LIB_NAME"
  for target in aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios; do
    echo "-- cargo build --release --target $target"
    (cd rust && cargo build --release --target "$target")
  done

  lipo -create \
    -output "$WORK_DIR/ios-sim.dylib" \
    "rust/target/aarch64-apple-ios-sim/release/lib$LIB_NAME.dylib" \
    "rust/target/x86_64-apple-ios/release/lib$LIB_NAME.dylib"

  make_ios_framework "rust/target/aarch64-apple-ios/release/lib$LIB_NAME.dylib" \
    "$WORK_DIR/ios-arm64/$LIB_NAME.framework"
  make_ios_framework "$WORK_DIR/ios-sim.dylib" \
    "$WORK_DIR/ios-arm64_x86_64-simulator/$LIB_NAME.framework"

  rm -rf "ios/$LIB_NAME/$LIB_NAME.xcframework"
  xcodebuild -create-xcframework \
    -framework "$WORK_DIR/ios-arm64/$LIB_NAME.framework" \
    -framework "$WORK_DIR/ios-arm64_x86_64-simulator/$LIB_NAME.framework" \
    -output "ios/$LIB_NAME/$LIB_NAME.xcframework"
  verify_no_symlinks "ios/$LIB_NAME/$LIB_NAME.xcframework"
}

build_macos() {
  echo "== macOS =="
  # See the note above: macOS cannot use a framework here, so the Rust core is
  # shipped as a plain dynamic library.
  export RUSTFLAGS="-C link-arg=-Wl,-install_name,@rpath/lib$LIB_NAME.dylib"
  for target in aarch64-apple-darwin x86_64-apple-darwin; do
    echo "-- cargo build --release --target $target"
    (cd rust && cargo build --release --target "$target")
  done

  lipo -create \
    -output "$WORK_DIR/lib$LIB_NAME.dylib" \
    "rust/target/aarch64-apple-darwin/release/lib$LIB_NAME.dylib" \
    "rust/target/x86_64-apple-darwin/release/lib$LIB_NAME.dylib"

  rm -rf "macos/$LIB_NAME/$LIB_NAME.xcframework"
  xcodebuild -create-xcframework \
    -library "$WORK_DIR/lib$LIB_NAME.dylib" \
    -output "macos/$LIB_NAME/$LIB_NAME.xcframework"
  verify_no_symlinks "macos/$LIB_NAME/$LIB_NAME.xcframework"
}

case "${1:-all}" in
  ios) build_ios ;;
  macos) build_macos ;;
  all) build_ios; build_macos ;;
  *) echo "usage: $0 [ios|macos|all]" >&2; exit 2 ;;
esac

echo
echo "Done ($VERSION). Commit the updated .xcframework directories."
