import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:args/args.dart';
import 'package:pub_update_checker/pub_update_checker.dart';

final newLine = Platform.isWindows ? '\r\n' : '\n';

// chrome.dart constants
// The amount of indentation the chrome.dart file has in the relevant lines
const indent = '      ';
const disableExtensions = "'--disable-extensions',";
const disableWebSecurity = "'--disable-web-security',";
const testType = "'--test-type',";

// args
const flagEnable = 'enable';
const flagDisable = 'disable';
const flagDisableBanner = 'disable-banner';
const optionFlutterPath = 'flutter-path';

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
  final flutterFolderPath = await getFlutterFolderPath(args);

  if (args[flagEnable]) {
    enable(flutterFolderPath, args);
  } else if (args[flagDisable]) {
    disable(flutterFolderPath, args);
  } else {
    print(magentaPen(parser.usage));
  }

  exit(0);
}

Future<String> getFlutterFolderPath(ArgResults args) async {
  if (args[optionFlutterPath] != null) {
    return args[optionFlutterPath];
  }
  final String flutterPath;
  if (Platform.isWindows) {
    final whereFlutterResult = await Process.run('where', ['flutter']);
    flutterPath = (whereFlutterResult.stdout as String).split('\n').first;
  } else {
    // macOS and Linux
    final whichFlutterResult = await Process.run('which', ['flutter']);
    final tmpFlutterPath = whichFlutterResult.stdout as String;
    // Get the real flutter path if it's a symbolic link.
    final realFlutterResult = await Process.run(
      'readlink',
      ['-f', tmpFlutterPath.trim()],
    );
    flutterPath = realFlutterResult.stdout as String;
  }

  return File(flutterPath.trim()).parent.parent.path;
}

// Delete flutter/bin/cache/flutter_tools.stamp
void deleteFlutterToolsStamp(String flutterPath) {
  final flutterToolsStampPath = '$flutterPath/bin/cache/flutter_tools.stamp';
  if (File(flutterToolsStampPath).existsSync()) {
    File(flutterToolsStampPath).deleteSync();
  }
}

// Find flutter/packages/flutter_tools/lib/src/web/chrome.dart
File findChromeDart(String flutterPath) {
  final chromeDartPath =
      '$flutterPath/packages/flutter_tools/lib/src/web/chrome.dart';
  return File(chromeDartPath);
}

void patch({
  required String flutterPath,
  required File chromeDartFile,
  required String chromeDartContents,
}) {
  print('Patching $flutterPath/packages/flutter_tools/lib/src/web/chrome.dart');
  chromeDartFile.writeAsStringSync(chromeDartContents);

  print('Deleting $flutterPath/bin/cache/flutter_tools.stamp');
  deleteFlutterToolsStamp(flutterPath);
}

void disable(String flutterPath, ArgResults args) {
  final chromeDartFile = findChromeDart(flutterPath);

  // Find '--disable-extensions' and add '--disable-web-security'
  final chromeDartContents = chromeDartFile.readAsStringSync();
  if (chromeDartContents.contains(disableWebSecurity)) {
    print(
      redPen('CORS checks are already disabled for Flutter\'s Chrome instance'),
    );
    exit(1);
  }
  var replacement = '$disableExtensions$newLine$indent$disableWebSecurity';
  if (args[flagDisableBanner]) {
    replacement += '$newLine$indent$testType';
  }
  final chromeDartContentsWithWebSecurity = chromeDartContents.replaceFirst(
    disableExtensions,
    replacement,
  );

  // Write the new contents to the file
  patch(
    flutterPath: flutterPath,
    chromeDartFile: chromeDartFile,
    chromeDartContents: chromeDartContentsWithWebSecurity,
  );

  print(
    greenPen('CORS checks are now disabled for Flutter\'s Chrome instance'),
  );
}

void enable(String flutterPath, ArgResults args) {
  final chromeDartFile = findChromeDart(flutterPath);

  // Find '--disable-web-security' and remove it
  final chromeDartContents = chromeDartFile.readAsStringSync();
  if (!chromeDartContents.contains(disableWebSecurity)) {
    print(
      redPen('CORS checks are already enabled for Flutter\'s Chrome instance'),
    );
    exit(1);
  }
  final chromeDartContentsWithoutWebSecurity = chromeDartContents
      .replaceFirst(
        '$indent$disableWebSecurity$newLine',
        '',
      )
      .replaceFirst(
        '$indent$testType$newLine',
        '',
      );

  // Write the new contents to the file
  patch(
    flutterPath: flutterPath,
    chromeDartFile: chromeDartFile,
    chromeDartContents: chromeDartContentsWithoutWebSecurity,
  );

  print(greenPen('CORS checks are now enabled for Flutter\'s Chrome instance'));
}
