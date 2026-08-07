import 'package:flutter/foundation.dart';

/// Conditional debug logger shared across the toolkit.
///
/// Emits [message] only in debug builds (via [kDebugMode]) so that development
/// traces never spam a profile or release console. In Flutter, [kDebugMode] is
/// true only in debug builds. Tests may pass `true` for [force] to capture
/// verbose output when a failure is being diagnosed.
///
/// Use this in place of raw `print()` calls in production code.
void debugLog(final String message, {final bool force = false}) {
  if (force || kDebugMode) {
    // ignore: avoid_print
    print(message);
  }
}
