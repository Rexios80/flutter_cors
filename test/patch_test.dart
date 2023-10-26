import 'dart:io';

import 'package:test/test.dart';
import '../bin/flutter_cors.dart' as fluttercors;

void main() {
  test('disable then enable', () {
    final unpatchedChromeDart = File('test_resources/unpatched_chrome.txt');
    final unpatchedChromeDartContents = unpatchedChromeDart.readAsStringSync();
    final patchedChromeDart = File('test_resources/patched_chrome.txt');
    final patchedChromeDartContents = patchedChromeDart.readAsStringSync();
    final unpatchedWebDriverServiceDart =
        File('test_resources/unpatched_web_driver_service.txt');
    final unpatchedWebDriverServiceDartContents =
        unpatchedWebDriverServiceDart.readAsStringSync();
    final patchedWebDriverServiceDart =
        File('test_resources/patched_web_driver_service.txt');
    final patchedWebDriverServiceDartContents =
        patchedWebDriverServiceDart.readAsStringSync();

    // test disabling
    final disabledChromeDartContents = fluttercors.contentsToDisable(
      file: unpatchedChromeDart,
      disableBanner: false,
    );
    final disabledWebDriverServiceDartContents = fluttercors.contentsToDisable(
      file: unpatchedWebDriverServiceDart,
      disableBanner: false,
    );

    expect(disabledChromeDartContents, patchedChromeDartContents);
    expect(
      disabledWebDriverServiceDartContents,
      patchedWebDriverServiceDartContents,
    );

    // test enabling
    final enabledChromeDartContents =
        fluttercors.contentsToEnable(file: patchedChromeDart);
    final enabledWebDriverServiceDartContents =
        fluttercors.contentsToEnable(file: patchedWebDriverServiceDart);

    expect(enabledChromeDartContents, unpatchedChromeDartContents);
    expect(
      enabledWebDriverServiceDartContents,
      unpatchedWebDriverServiceDartContents,
    );
  });
}
