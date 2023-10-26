import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:args/args.dart';
import 'package:pub_update_checker/pub_update_checker.dart';

final newLine = Platform.isWindows ? '\r\n' : '\n';

// content constants
const disableExtensions = "'--disable-extensions',";
const disableWebSecurity = "'--disable-web-security',";
const testType = "'--test-type',";

// args
const flagEnable = 'enable';
const flagDisable = 'disable';
const flagDisableBanner = 'disable-banner';
const optionFlutterPath = 'flutter-path';

const filesToPatch = [
  '/packages/flutter_tools/lib/src/web/chrome.dart',
  '/packages/flutter_tools/lib/src/drive/web_driver_service.dart',
];
const stampPath = '/bin/cache/flutter_tools.stamp';

final parser = ArgParser()
  ..addFlag(flagEnable, abbr: 'e', negatable: false, help: 'Enable CORS checks')
  ..addFlag(
    flagDisable,
    abbr: 'd',
    negatable: false,
    help: 'Disable CORS checks',
  )
  ..addFlag(
    flagDisableBanner,
    abbr: 'b',
    negatable: false,
    help: 'Disable the warning banner in Chrome',
  )
  ..addOption(
    optionFlutterPath,
    abbr: 'p',
    help: 'Flutter root path (determined automatically if not specified)',
    valueHelp: 'path',
  );

final magentaPen = AnsiPen()..magenta();
final greenPen = AnsiPen()..green();
final yellowPen = AnsiPen()..yellow();
final redPen = AnsiPen()..red();

/// Based on https://stackoverflow.com/a/66879350/8174191
void main(List<String> arguments) async {
  final newVersion = await PubUpdateChecker.check();
  if (newVersion != null) {
    print(
      yellowPen(
        'There is an update available: $newVersion. Run `dart pub global activate flutter_cors` to update.',
      ),
    );
  }

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (_) {
    print(magentaPen(parser.usage));
    exit(1);
  }
  final flutterFolderPath = getFlutterFolderPath(args);

  if (args[flagEnable]) {
    print('Enabling CORS checks');
    patch(
      flutterPath: flutterFolderPath,
      paths: filesToPatch,
      patch: (file) => contentsToEnable(file: file),
    );
    print(greenPen('CORS checks are now enabled'));
  } else if (args[flagDisable]) {
    print('Disabling CORS checks');
    final disableBanner = args[flagDisableBanner];
    patch(
      flutterPath: flutterFolderPath,
      paths: filesToPatch,
      patch: (file) =>
          contentsToDisable(file: file, disableBanner: disableBanner),
    );
    print(greenPen('CORS checks are now disabled'));
  } else {
    print(magentaPen(parser.usage));
  }

  exit(0);
}

String getFlutterFolderPath(ArgResults args) {
  if (args[optionFlutterPath] != null) {
    return args[optionFlutterPath];
  }
  final String flutterPath;
  if (Platform.isWindows) {
    final whereFlutterResult = Process.runSync('where', ['flutter']);
    flutterPath = (whereFlutterResult.stdout as String).split('\n').first;
  } else {
    // macOS and Linux
    final whichFlutterResult = Process.runSync('which', ['flutter']);
    flutterPath = whichFlutterResult.stdout as String;
  }

  final resolvedFlutterPath =
      File(flutterPath.trim()).resolveSymbolicLinksSync();
  return File(resolvedFlutterPath).parent.parent.path;
}

void patch({
  required String flutterPath,
  required List<String> paths,
  required String? Function(File file) patch,
}) {
  var modified = false;
  for (final path in paths) {
    final file = File('$flutterPath$path');
    final newContents = patch(file);
    if (newContents != null) {
      print('Patching ${file.path}');
      file.writeAsStringSync(newContents);
      modified = true;
    } else {
      print(yellowPen('Nothing to patch in ${file.path}'));
    }
  }

  if (modified) {
    final flutterToolsStamp = File('$flutterPath$stampPath');
    if (flutterToolsStamp.existsSync()) {
      print('Deleting ${flutterToolsStamp.path}');
      flutterToolsStamp.deleteSync();
    } else {
      print(yellowPen('Stamp file does not exist'));
    }
  } else {
    print(yellowPen('No files patched'));
  }
}

String? contentsToDisable({
  required File file,
  required bool disableBanner,
}) {
  final contents = file.readAsStringSync();
  if (contents.contains(disableWebSecurity)) {
    return null;
  } else {
    return contents.replaceFirstMapped(RegExp('( +)$disableExtensions'), (m) {
      final indent = m[1]!;
      var replacement =
          '$indent$disableExtensions$newLine$indent$disableWebSecurity';
      if (disableBanner) {
        replacement += '$newLine$indent$testType';
      }
      return replacement;
    });
  }
}

String? contentsToEnable({required File file}) {
  final contents = file.readAsStringSync();
  if (!contents.contains(disableWebSecurity)) {
    return null;
  } else {
    final indent = RegExp('( +)$disableExtensions').firstMatch(contents)![1]!;
    return contents
        .replaceFirst('$indent$disableWebSecurity$newLine', '')
        .replaceFirst('$indent$testType$newLine', '');
  }
}
