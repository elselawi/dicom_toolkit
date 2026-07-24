/// A dummy web plugin class to satisfy Flutter's plugin system.
/// The actual web implementation is handled directly by flutter_rust_bridge
/// via JS interop and WASM.
class DicomToolkitWeb {
  /// Registers the web plugin. This is a no-op — flutter_rust_bridge handles
  /// all WASM loading internally.
  static void registerWith(final dynamic registrar) {
    // No-op — flutter_rust_bridge handles all WASM loading internally.
  }
}
