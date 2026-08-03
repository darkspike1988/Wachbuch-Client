import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android registers isolated Wachbuch connect URI schemes', () async {
    final manifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();
    final gradle = await File('android/app/build.gradle.kts').readAsString();

    expect(manifest, contains('android.intent.action.VIEW'));
    expect(manifest, contains('android.intent.category.BROWSABLE'));
    expect(manifest, contains('android:scheme="\${appScheme}"'));
    expect(manifest, contains('android:host="connect"'));
    expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));

    expect(
      gradle,
      contains('manifestPlaceholders["appScheme"] = "wachbuch"'),
    );
    expect(
      gradle,
      contains('manifestPlaceholders["appScheme"] = "wachbuch-internal"'),
    );
    expect(gradle, contains('applicationIdSuffix = ".internal"'));
    expect(gradle, contains('manifestPlaceholders["appLabel"] = "Wachbuch Internal"'));
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
