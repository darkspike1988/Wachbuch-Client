import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wachbuch_mobile/auth/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('stores server URL separately from secure API token', () async {
    const secure = FlutterSecureStorage();
    final store = SessionStore(secureStorage: secure);

    await store.writeServerUrl('https://wache.example.org');
    await store.writeToken('wb_secret');

    expect(await store.readServerUrl(), 'https://wache.example.org');
    expect(await store.readToken(), 'wb_secret');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wachbuch_server_url'), 'https://wache.example.org');
    expect(prefs.getString('wachbuch_api_token'), isNull);
  });

  test('clearToken preserves the configured server', () async {
    final store = SessionStore();
    await store.writeServerUrl('https://wache.example.org');
    await store.writeToken('wb_secret');

    await store.clearToken();

    expect(await store.readToken(), isNull);
    expect(await store.readServerUrl(), 'https://wache.example.org');
  });

  test('clearAll removes server and token', () async {
    final store = SessionStore();
    await store.writeServerUrl('https://wache.example.org');
    await store.writeToken('wb_secret');

    await store.clearAll();

    expect(await store.readToken(), isNull);
    expect(await store.readServerUrl(), isNull);
  });

  test('token expiry is detected from stored timestamp', () async {
    final store = SessionStore();
    await store.writeToken(
      'wb_secret',
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );

    expect(await store.isTokenExpired(), isTrue);
    expect(await store.readTokenExpiresAt(), isNotNull);
  });

  test('pasted token without expiry falls back to a 90-day lifetime', () async {
    final store = SessionStore();
    await store.writeToken('wb_pasted');

    final expiresAt = await store.readTokenExpiresAt();
    expect(expiresAt, isNotNull);
    final drift = expiresAt!.difference(DateTime.now());
    expect(drift.inDays, greaterThanOrEqualTo(89));
    expect(drift.inDays, lessThanOrEqualTo(90));
    expect(await store.isTokenExpired(), isFalse);
  });

  test('explicit expires_at overrides the default and persists', () async {
    final store = SessionStore();
    final inFiveDays = DateTime.now().add(const Duration(days: 5));
    await store.writeToken('wb_explicit', expiresAt: inFiveDays);

    final stored = await store.readTokenExpiresAt();
    expect(stored, isNotNull);
    expect(await store.isTokenExpired(), isFalse);
    expect(await store.isTokenExpired(now: inFiveDays.add(const Duration(days: 1))), isTrue);
  });

  test('clearToken removes the expiry alongside the token', () async {
    final store = SessionStore();
    await store.writeToken('wb_secret');

    await store.clearToken();

    expect(await store.readToken(), isNull);
    expect(await store.readTokenExpiresAt(), isNull);
  });
}
