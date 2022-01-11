import 'dart:io';

final newLine = Platform.isWindows ? '\r\n' : '\n';

/// Based on https://stackoverflow.com/a/66879350/8174191
void main(List<String> arguments) async {
  final String flutterPath;
  if (Platform.isWindows) {
    final whereFlutterResult = await Process.run('where', ['flutter']);
    flutterPath = (whereFlutterResult.stdout as String).split('\n').first;
  } else {
    // macOS and Linux
    final whichFlutterResult = await Process.run('which', ['flutter']);
    flutterPath = whichFlutterResult.stdout as String;
  }

  final flutterFolderPath = File(flutterPath.trim()).parent.parent.path;

  if (arguments.contains('reset')) {
    reset(flutterFolderPath);
  } else {
    disable(flutterFolderPath);
  }
}

// Delete flutter/bin/cache/flutter_tools.stamp
void deleteFlutterToolsStamp(String flutterPath) {
  final flutterToolsStampPath = '$flutterPath/bin/cache/flutter_tools.stamp';
  if (File(flutterToolsStampPath).existsSync()) {
    File(flutterToolsStampPath).deleteSync();
  }
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

// Find flutter/packages/flutter_tools/lib/src/web/chrome.dart
File findChromeDart(String flutterPath) {
  final chromeDartPath =
      '$flutterPath/packages/flutter_tools/lib/src/web/chrome.dart';
  return File(chromeDartPath);
}

void disable(String flutterPath) {
  final chromeDartFile = findChromeDart(flutterPath);

  // Find '--disable-extensions' and add '--disable-web-security'
  final chromeDartContents = chromeDartFile.readAsStringSync();
  if (chromeDartContents.contains('--disable-web-security')) {
    print('CORS is already disabled for Flutter\'s Chrome instance');
    exit(0);
  }
  final chromeDartContentsWithWebSecurity = chromeDartContents.replaceFirst(
    "'--disable-extensions',",
    "'--disable-extensions',$newLine      '--disable-web-security',",
  );

  // Write the new contents to the file
  patch(
    flutterPath: flutterPath,
    chromeDartFile: chromeDartFile,
    chromeDartContents: chromeDartContentsWithWebSecurity,
  );

  print('CORS is now disabled for Flutter\'s Chrome instance');
}

void reset(String flutterPath) {
  final chromeDartFile = findChromeDart(flutterPath);

  // Find '--disable-web-security' and remove it
  final chromeDartContents = chromeDartFile.readAsStringSync();
  if (!chromeDartContents.contains('--disable-web-security')) {
    print('CORS is not disabled for Flutter\'s Chrome instance');
    exit(0);
  }
  final chromeDartContentsWithoutWebSecurity = chromeDartContents.replaceFirst(
    "      '--disable-web-security',$newLine",
    '',
  );

  // Write the new contents to the file
  patch(
    flutterPath: flutterPath,
    chromeDartFile: chromeDartFile,
    chromeDartContents: chromeDartContentsWithoutWebSecurity,
  );

  print('CORS is now enabled for Flutter\'s Chrome instance');
}
