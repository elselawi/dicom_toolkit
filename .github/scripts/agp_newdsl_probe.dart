// AGP new-DSL probe.
//
// Verifies that dicom_toolkit still configures and packages its Rust binaries when a
// consumer sets `android.newDsl=true` (the AGP 9 default, and the only mode AGP 10 will
// support).
//
// Why this harness exists instead of just building the example app with the flag flipped:
// Flutter 3.47's own Gradle plugin cannot run with `android.newDsl=true`. It fails in
// `com.flutter.gradle.FlutterPlugin.addFlutterTasks` (FlutterPlugin.kt:354) with
//
//   ClassCastException: com.android.build.gradle.internal.dsl.ApplicationExtensionImpl
//       cannot be cast to com.android.build.gradle.AbstractAppExtension
//
// and Flutter prints its own "Flutter Fix" box asking you to "update flutter or opt out of
// `android.newDsl`". No dicom_toolkit code has run at that point, so the flag cannot be
// exercised end-to-end through a Flutter app today. This probe therefore builds a plain
// AGP application which applies a *stub* Flutter plugin (same class name and shape that
// cargokit looks for) and depends on the real plugin module. That is enough to run every
// AGP API cargokit touches: `androidComponents.onVariants`, `sdkComponents.sdkDirectory`,
// `variant.minSdk`, `variant.sources.jniLibs`, plus the plugin module's own `android { }`
// block.
//
// Usage (from the package root):
//   dart run .github/scripts/agp_newdsl_probe.dart [--agp <version>] [--keep]
//
// Exit code 0 means: the module configured under the new DSL and `libdicom_toolkit.so` was
// packaged for every ABI cargokit was asked to build.

import 'dart:io';
import 'dart:typed_data';

const _expectedAbis = <String>[
  'arm64-v8a',
  'armeabi-v7a',
  'x86',
  'x86_64',
];

Future<void> main(final List<String> args) async {
  final androidDir = Directory('${Directory.current.path}/android');
  if (!File('${androidDir.path}/build.gradle').existsSync()) {
    _fail('Run this from the dicom_toolkit package root '
        '(no android/build.gradle found in ${androidDir.path}).');
  }

  final agpVersion = _option(args, '--agp') ?? '9.1.0';
  final keep = args.contains('--keep');

  final workDir = Directory.systemTemp.createTempSync('dicom_toolkit_newdsl_');
  stdout.writeln('new-DSL probe workspace: ${workDir.path}');

  try {
    // `flutter create` provides a working Gradle wrapper pinned to the Gradle version
    // Flutter's template uses, so no binary wrapper files live in the package.
    await _run(
      'flutter',
      ['create', '--platforms=android', '--org', 'com.example', 'probe'],
      workingDirectory: workDir.path,
    );

    final harnessAndroid = Directory('${workDir.path}/probe/android');
    final flutterRoot =
        _readProperty('${harnessAndroid.path}/local.properties', 'flutter.sdk');
    if (flutterRoot == null) {
      _fail(
          '`flutter create` did not write flutter.sdk to android/local.properties.');
    }

    _writeHarness(harnessAndroid, agpVersion, androidDir.path);

    final exitCode = await _run(
      _gradlew(harnessAndroid.path),
      [':app:assembleDebug', '--stacktrace'],
      workingDirectory: harnessAndroid.path,
      environment: {'FLUTTER_ROOT': flutterRoot},
      allowFailure: true,
    );
    if (exitCode != 0) {
      _fail(
          'Assembling the new-DSL probe app failed (see the Gradle output above).');
    }

    final apk = Directory('${harnessAndroid.path}/out/app/outputs/apk/debug')
        .listSync()
        .whereType<File>()
        .where((final f) => f.path.endsWith('.apk'))
        .toList();
    if (apk.isEmpty) {
      _fail('The new-DSL probe build produced no APK.');
    }

    final entries = _zipEntries(apk.first);
    final missing = _expectedAbis
        .where((final abi) => !entries.contains('lib/$abi/libdicom_toolkit.so'))
        .toList();
    if (missing.isNotEmpty) {
      _fail(
          'libdicom_toolkit.so is missing from the APK for: ${missing.join(', ')}\n'
          'APK entries:\n  ${entries.join('\n  ')}');
    }

    stdout.writeln(
        'OK: android.newDsl=true builds, and libdicom_toolkit.so is packaged '
        'for ${_expectedAbis.join(', ')}.');
  } finally {
    if (keep) {
      stdout.writeln('Kept ${workDir.path} for inspection.');
    } else {
      try {
        workDir.deleteSync(recursive: true);
      } on FileSystemException {
        // A locked Gradle daemon log must not fail the probe.
        stderr.writeln('Note: could not remove ${workDir.path}.');
      }
    }
  }
}

void _writeHarness(final Directory androidDir, final String agpVersion,
    final String pluginAndroidDir) {
  File('${androidDir.path}/app/build.gradle.kts').deleteSync();
  // Flutter-only generated sources: they reference the Flutter embedding, which this app
  // deliberately does not depend on.
  File('${androidDir.path}/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java')
      .deleteSync();
  final kotlinDir = Directory('${androidDir.path}/app/src/main/kotlin');
  if (kotlinDir.existsSync()) kotlinDir.deleteSync(recursive: true);
  File('${androidDir.path}/app/build.gradle')
      .writeAsStringSync(_appBuildGradle);
  File('${androidDir.path}/app/src/main/AndroidManifest.xml')
      .writeAsStringSync(_manifest);
  File('${androidDir.path}/settings.gradle.kts')
      .writeAsStringSync(_settingsGradleKts(agpVersion, pluginAndroidDir));
  File('${androidDir.path}/build.gradle').writeAsStringSync(_rootBuildGradle);
  File('${androidDir.path}/gradle.properties')
      .writeAsStringSync(_gradleProperties);

  final stubDir = Directory(
      '${androidDir.path}/buildSrc/src/main/groovy/com/flutter/gradle')
    ..createSync(recursive: true);
  File('${androidDir.path}/buildSrc/build.gradle')
      .writeAsStringSync(_buildSrcBuildGradle);
  File('${stubDir.path}/FlutterPlugin.groovy')
      .writeAsStringSync(_stubFlutterPlugin);
  File('${stubDir.path}/FlutterPluginUtils.groovy')
      .writeAsStringSync(_stubFlutterPluginUtils);
}

String _gradlew(final String androidDir) =>
    Platform.isWindows ? '$androidDir\\gradlew.bat' : '$androidDir/gradlew';

String? _option(final List<String> args, final String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

Never _fail(final String message) {
  stderr.writeln('ERROR: $message');
  exit(1);
}

/// Reads `key=value` from a java-properties file, un-escaping Windows separators.
String? _readProperty(final String path, final String key) {
  final file = File(path);
  if (!file.existsSync()) return null;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('$key=')) {
      return line.substring(key.length + 1).replaceAll('\\\\', '\\');
    }
  }
  return null;
}

Future<int> _run(
  final String executable,
  final List<String> args, {
  required final String workingDirectory,
  final Map<String, String> environment = const {},
  final bool allowFailure = false,
}) async {
  stdout.writeln('> $executable ${args.join(' ')}');
  // inheritStdio: stream child output straight to the console. (Piping with
  // `process.stdout.pipe(stdout)` would *close* stdout once the child exits.)
  final process = await Process.start(
    executable,
    args,
    workingDirectory: workingDirectory,
    environment: environment,
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0 && !allowFailure) {
    _fail('`$executable ${args.join(' ')}` failed with exit code $exitCode.');
  }
  return exitCode;
}

/// Minimal ZIP central-directory reader, so the probe needs no extra dependencies.
List<String> _zipEntries(final File archive) {
  final raf = archive.openSync();
  try {
    final length = raf.lengthSync();
    final tailSize = length < 66000 ? length : 66000;
    final tail = Uint8List(tailSize);
    raf.setPositionSync(length - tailSize);
    raf.readIntoSync(tail);

    var eocd = -1;
    for (var i = tail.length - 22; i >= 0; i--) {
      if (tail[i] == 0x50 &&
          tail[i + 1] == 0x4b &&
          tail[i + 2] == 0x05 &&
          tail[i + 3] == 0x06) {
        eocd = i;
        break;
      }
    }
    if (eocd == -1) return const [];

    final entryCount = tail[eocd + 10] | (tail[eocd + 11] << 8);
    final cdOffset = tail[eocd + 16] |
        (tail[eocd + 17] << 8) |
        (tail[eocd + 18] << 16) |
        (tail[eocd + 19] << 24);

    final names = <String>[];
    raf.setPositionSync(cdOffset);
    for (var i = 0; i < entryCount; i++) {
      final header = Uint8List(46);
      raf.readIntoSync(header);
      final nameLength = header[28] | (header[29] << 8);
      final extraLength = header[30] | (header[31] << 8);
      final commentLength = header[32] | (header[33] << 8);
      final nameBytes = Uint8List(nameLength);
      raf.readIntoSync(nameBytes);
      names.add(String.fromCharCodes(nameBytes));
      raf.setPositionSync(raf.positionSync() + extraLength + commentLength);
    }
    return names;
  } finally {
    raf.closeSync();
  }
}

String _settingsGradleKts(
        final String agpVersion, final String pluginAndroidDir) =>
    '''
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("com.android.application") version "$agpVersion" apply false
    id("com.android.library") version "$agpVersion" apply false
}

include(":app")
include(":dicom_toolkit")

// The real dicom_toolkit Android library module.
project(":dicom_toolkit").projectDir = file("${pluginAndroidDir.replaceAll('\\', '/')}")
''';

const _rootBuildGradle = r'''
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Keep every build output inside the probe so the checked-out package stays clean.
subprojects {
    layout.buildDirectory.set(file("${rootDir}/out/${project.name}"))
}

// cargokit discovers the Flutter plugin on the root project, so the stub must be applied
// before the plugin module is configured.
project(":dicom_toolkit").evaluationDependsOn(":app")
''';

const _gradleProperties = r'''
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G
android.useAndroidX=true
# The point of this probe.
android.newDsl=true
android.builtInKotlin=false
''';

const _buildSrcBuildGradle = r'''
plugins {
    id 'groovy'
}

repositories {
    mavenCentral()
}

dependencies {
    implementation localGroovy()
}
''';

const _stubFlutterPlugin = r'''
// Minimal stand-in for Flutter's Gradle plugin. cargokit looks for a plugin instance whose
// class is `com.flutter.gradle.FlutterPlugin` (or named `FlutterPlugin`) and reads
// `project` and `getTargetPlatforms()` off it.
package com.flutter.gradle

import org.gradle.api.Plugin
import org.gradle.api.Project

class FlutterPlugin implements Plugin<Project> {

    Project project

    @Override
    void apply(Project project) {
        this.project = project
    }

    List<String> getTargetPlatforms() {
        return ['android-arm', 'android-arm64', 'android-x64']
    }
}
''';

const _stubFlutterPluginUtils = r'''
package com.flutter.gradle

import org.gradle.api.Project

class FlutterPluginUtils {

    static List<String> getTargetPlatforms(Project project) {
        return ['android-arm', 'android-arm64', 'android-x64']
    }
}
''';

const _manifest = '''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="dicom_toolkit new-DSL probe" />
</manifest>
''';

/// Groovy on purpose: `apply plugin: <class>` lets the stub plugin come from buildSrc
/// without publishing a Gradle plugin marker.
const _appBuildGradle = r'''
import com.flutter.gradle.FlutterPlugin

plugins {
    id 'com.android.application'
}

// Stand-in for `dev.flutter.flutter-gradle-plugin` (see buildSrc).
apply plugin: FlutterPlugin

android {
    namespace = 'com.example.dicomtoolkitprobe'
    compileSdk = 36
    ndkVersion = '28.2.13676358'

    defaultConfig {
        applicationId = 'com.example.dicomtoolkitprobe'
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = '1.0'
    }
}

dependencies {
    implementation project(':dicom_toolkit')
}
''';
