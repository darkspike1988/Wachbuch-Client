import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android registers the wachbuch connect URI scheme', () async {
    final manifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();

    expect(manifest, contains('android.intent.action.VIEW'));
    expect(manifest, contains('android.intent.category.BROWSABLE'));
    expect(manifest, contains('android:scheme="wachbuch"'));
    expect(manifest, contains('android:host="connect"'));
    expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
  });

  test('iOS registers the wachbuch URI scheme', () async {
    final plist = await File('ios/Runner/Info.plist').readAsString();

    expect(plist, contains('<key>CFBundleURLTypes</key>'));
    expect(plist, contains('<string>wachbuch</string>'));
    expect(plist, contains('<key>NSLocationWhenInUseUsageDescription</key>'));
    expect(plist, contains('Sonnenaufgang und Sonnenuntergang'));
    expect(plist, contains('<key>ITSAppUsesNonExemptEncryption</key>'));
  });
}
