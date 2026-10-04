import 'package:flutter_rust_bridge/flutter_rust_bridge.dart'
    show loadExternalLibrary;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibraryLoaderConfig;

import '../rust/frb_generated.dart';

/// Initializes the Rust bindings on web by loading the compiled WASM bundle.
///
/// The artifacts live under the Flutter asset path
/// (`assets/packages/dicom_toolkit/web/pkg/`) so that `flutter build web`
/// bundles them automatically — no manual copy step is required.
Future<void> initializeRustLibrary() async {
  final lib = await loadExternalLibrary(
    const ExternalLibraryLoaderConfig(
      stem: 'dicom_toolkit',
      ioDirectory: 'rust/target/release/',
      webPrefix: 'assets/packages/dicom_toolkit/web/pkg/',
    ),
  );
  return RustLib.init(externalLibrary: lib);
}
