import 'dart:io' show Platform;

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart'
    show loadExternalLibrary;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;

import '../core/exceptions/dicom_exceptions.dart';
import '../debug_log.dart';
import '../rust/frb_generated.dart';

/// Initializes the Rust bindings on native platforms.
///
/// Android, Windows and Linux load the shared library packaged alongside the
/// app through the generated default loader.
Future<void> initializeRustLibrary() async {
  if (Platform.isIOS || Platform.isMacOS) {
    return _initializeApple();
  }
  return RustLib.init();
}

/// Initializes the Rust bindings on iOS and macOS.
///
/// Depending on the dependency manager, the Rust core either ends up in the
/// app binary (CocoaPods, where the podspec injects it with `-force_load`) or
/// in an embedded framework (Swift Package Manager, which links the prebuilt
/// `dicom_toolkit.xcframework`). Neither is a `dlopen`-able path that the
/// generated loader could find — it resolves against the working directory,
/// while those images live in the app bundle.
///
/// Resolving the symbols from the process image is therefore tried first. It
/// works for both layouts and needs no knowledge of either.
///
/// When running from source (`flutter test`, `dart run`) the Rust code is not
/// part of the process at all, so the dylib produced by `cargo build --release`
/// is loaded instead — which is also the fallback for set-ups where the symbols
/// are not in the process image.
Future<void> _initializeApple() async {
  final processLibrary = ExternalLibrary.process(iKnowHowToUseIt: true);
  if (_exportsRustCore(processLibrary)) {
    debugLog('[DART] Rust core found in the process image');
    return RustLib.init(externalLibrary: processLibrary);
  }

  try {
    final library =
        await loadExternalLibrary(RustLib.kDefaultExternalLibraryLoaderConfig);
    if (_exportsRustCore(library)) {
      return RustLib.init(externalLibrary: library);
    }
  } catch (e) {
    debugLog('[DART] Could not load a dynamic Rust library: $e');
  }

  throw const DicomInitializationException(
    'Could not initialize the DICOM engine: the Rust core is not linked into '
    'this app. With CocoaPods the podspec links it into the app target using '
    '`-force_load` and `DEAD_CODE_STRIPPING = NO`; if those settings were '
    'removed — or the pod compiled differently — the linker silently drops the '
    'whole Rust core in Release builds and the app fails here instead. With '
    'Swift Package Manager the prebuilt dicom_toolkit.xcframework must be '
    'embedded in the app. Reinstall dependencies (`flutter clean` followed by '
    '`flutter pub get`), and see the "iOS and macOS" section of the '
    'dicom_toolkit README.',
  );
}

/// Returns true when [library] exports the flutter_rust_bridge runtime symbol.
///
/// Probing before calling [RustLib.init] avoids retrying initialization after a
/// partially-applied failure.
bool _exportsRustCore(final ExternalLibrary library) {
  try {
    library.ffiDynamicLibrary.lookup('frb_get_rust_content_hash');
    return true;
  } on Object {
    return false;
  }
}
