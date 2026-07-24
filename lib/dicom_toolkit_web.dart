import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// A dummy web plugin class to satisfy Flutter's plugin system.
/// The actual web implementation is handled directly by flutter_rust_bridge via JS interop and WASM.
class DicomToolkitWeb {
  static void registerWith(Registrar registrar) {
    // No-op
  }
}
