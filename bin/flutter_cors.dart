import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:args/args.dart';
import 'package:pub_update_checker/pub_update_checker.dart';

final newLine = Platform.isWindows ? '\r\n' : '\n';

// chrome.dart constants & web_driver_service.dart constants
/// The amount of indentation the chrome.dart file has in the relevant lines
final indentChromeDart = ' ' * 6;

/// The amount of indentation the web_driver_service.dart file has in the relevant lines
final indentWebDriverServiceDart = ' ' * 12;
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
    enable(flutterFolderPath);
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
    flutterPath = whichFlutterResult.stdout as String;
  }

  final resolvedFlutterPath =
      File(flutterPath.trim()).resolveSymbolicLinksSync();
  return File(resolvedFlutterPath).parent.parent.path;
}

// Delete flutter/bin/cache/flutter_tools.stamp
void deleteFlutterToolsStamp(String flutterPath) {
  final flutterToolsStamp = File('$flutterPath/bin/cache/flutter_tools.stamp');
  print('Deleting ${flutterToolsStamp.path}');
  if (flutterToolsStamp.existsSync()) {
    flutterToolsStamp.deleteSync();
  }
}

// Find flutter/packages/flutter_tools/lib/src/web/chrome.dart
File findChromeDart(String flutterPath) {
  return File('$flutterPath/packages/flutter_tools/lib/src/web/chrome.dart');
}

// Find flutter/packages/flutter_tools/lib/src/drive/web_driver_service.dart
File findWebDriverServiceDart(String flutterPath) {
  return File(
    '$flutterPath/packages/flutter_tools/lib/src/drive/web_driver_service.dart',
  );
}

void patch({
  required String flutterPath,
  required File chromeDartFile,
  required String? chromeDartContents,
  required File webDriverServiceDartFile,
  required String? webDriverServiceDartContents,
}) {
  if (chromeDartContents != null) {
    print('Patching ${chromeDartFile.path}');
    chromeDartFile.writeAsStringSync(chromeDartContents);
  }

  if (webDriverServiceDartContents != null) {
    print('Patching ${webDriverServiceDartFile.path}');
    webDriverServiceDartFile.writeAsStringSync(webDriverServiceDartContents);
  }

  if (chromeDartContents != null || webDriverServiceDartContents != null) {
    deleteFlutterToolsStamp(flutterPath);
  } else {
    print(yellowPen('Nothing to patch'));
  }
}

String? contentsToDisable({
  required File file,
  required String indent,
  required bool disableBanner,
}) {
  final contents = file.readAsStringSync();
  if (contents.contains(disableWebSecurity)) {
    print(redPen('CORS checks are already disabled in ${file.path}'));
    return null;
  } else {
    var replacement = '$disableExtensions$newLine$indent$disableWebSecurity';
    if (disableBanner) {
      replacement += '$newLine$indent$testType';
    }
    return contents.replaceFirst(disableExtensions, replacement);
  }
}

void disable(String flutterPath, ArgResults args) {
  final disableBanner = args[flagDisableBanner];

  final chromeDartFile = findChromeDart(flutterPath);
  final newChromeDartContents = contentsToDisable(
    file: chromeDartFile,
    indent: indentChromeDart,
    disableBanner: disableBanner,
  );

  final webDriverServiceDartFile = findWebDriverServiceDart(flutterPath);
  final newWebDriverServiceDartContents = contentsToDisable(
    file: webDriverServiceDartFile,
    indent: indentWebDriverServiceDart,
    disableBanner: disableBanner,
  );

  // Write the new contents to the file
  patch(
    flutterPath: flutterPath,
    chromeDartFile: chromeDartFile,
    chromeDartContents: newChromeDartContents,
    webDriverServiceDartFile: webDriverServiceDartFile,
    webDriverServiceDartContents: newWebDriverServiceDartContents,
  );

  print(greenPen('CORS checks are now disabled'));
}

String? contentsToEnable({required File file, required String indent}) {
  final contents = file.readAsStringSync();
  if (!contents.contains(disableWebSecurity)) {
    print(redPen('CORS checks are already enabled in ${file.path}'));
    return null;
  } else {
    return contents
        .replaceFirst('$indent$disableWebSecurity$newLine', '')
        .replaceFirst('$indent$testType$newLine', '');
  }
}

void enable(String flutterPath) {
  final chromeDartFile = findChromeDart(flutterPath);
  final newChromeDartContents =
      contentsToEnable(file: chromeDartFile, indent: indentChromeDart);

  final webDriverServiceDartFile = findWebDriverServiceDart(flutterPath);
  final newWebDriverServiceDartContents = contentsToEnable(
    file: webDriverServiceDartFile,
    indent: indentWebDriverServiceDart,
  );

  // Write the new contents to the file
  patch(
    flutterPath: flutterPath,
    chromeDartFile: chromeDartFile,
    chromeDartContents: newChromeDartContents,
    webDriverServiceDartFile: webDriverServiceDartFile,
    webDriverServiceDartContents: newWebDriverServiceDartContents,
  );

  print(greenPen('CORS checks are now enabled'));
}
