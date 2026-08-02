import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/api/server_address.dart';

void main() {
  test('normalizeServerUrl adds https and strips slash', () {
    expect(
      normalizeServerUrl('wache.example.org/'),
      'https://wache.example.org',
    );
    expect(
      normalizeServerUrl('https://wache.example.org'),
      'https://wache.example.org',
    );
  });

  test('parseServerAddress strips path to origin', () {
    expect(
      parseServerAddress('https://wache.example.org/anmelden/'),
      'https://wache.example.org',
    );
  });

  test('parseServerAddress accepts JSON and deep link', () {
    expect(
      parseServerAddress('{"url":"https://wache.example.org"}'),
      'https://wache.example.org',
    );
    expect(
      parseServerAddress(
        'wachbuch://connect?url=https%3A%2F%2Fwache.example.org',
      ),
      'https://wache.example.org',
    );
  });

  test('parseServerAddress preserves explicit ports', () {
    expect(
      parseServerAddress('https://wache.example.org:8443/anmelden/'),
      'https://wache.example.org:8443',
    );
  });

  test('parseServerAddress rejects unsupported schemes', () {
    expect(
      () => parseServerAddress('ftp://wache.example.org'),
      throwsArgumentError,
    );
  });

  test('parseServerAddress rejects incomplete Wachbuch deep links', () {
    expect(() => parseServerAddress('wachbuch://connect'), throwsArgumentError);
  });

  test('parseServerAddress rejects malformed JSON payloads clearly', () {
    expect(() => parseServerAddress('{"url":'), throwsArgumentError);
  });

  test(
    'parseServerAddress rejects HTTP when insecure transport is disabled',
    () {
      expect(
        () => parseServerAddress(
          'http://wache.example.org',
          allowInsecure: false,
        ),
        throwsArgumentError,
      );
    },
  );

  test('parseServerAddress permits HTTP only when explicitly enabled', () {
    expect(
      parseServerAddress('http://192.168.1.20:8090', allowInsecure: true),
      'http://192.168.1.20:8090',
    );
  });
}
