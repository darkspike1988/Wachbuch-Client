import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/client.dart';

void main() {
  group('ApiException', () {
    test('isMfaRequired returns true for mfa_required code', () {
      final exception = ApiException(
        403,
        'MFA erforderlich',
        code: 'mfa_required',
      );
      expect(exception.isMfaRequired, isTrue);
    });

    test('isMfaRequired returns true for mfa_setup_required code', () {
      final exception = ApiException(
        403,
        'MFA muss eingerichtet werden',
        code: 'mfa_setup_required',
      );
      expect(exception.isMfaRequired, isTrue);
    });

    test('isMfaRequired returns true for MFA in message', () {
      final exception = ApiException(
        403,
        'MFA ist erforderlich',
      );
      expect(exception.isMfaRequired, isTrue);
    });

    test('isMfaRequired returns false for other errors', () {
      final exception = ApiException(
        403,
        'Zugriff verweigert',
        code: 'forbidden',
      );
      expect(exception.isMfaRequired, isFalse);
    });

    test('toString includes code and correlationId', () {
      final exception = ApiException(
        403,
        'Testfehler',
        code: 'test_error',
        correlationId: 'abc123',
      );
      final str = exception.toString();
      expect(str, contains('403'));
      expect(str, contains('test_error'));
      expect(str, contains('abc123'));
    });

    test('toString omits empty correlationId', () {
      final exception = ApiException(
        403,
        'Testfehler',
        code: 'test_error',
      );
      final str = exception.toString();
      expect(str, contains('403'));
      expect(str, contains('test_error'));
      expect(str, isNot(contains('[]')));
    });
  });

  group('API Error Codes', () {
    test('rate_limit error code is handled', () {
      final exception = ApiException(
        429,
        'Zu viele Anfragen',
        code: 'rate_limit',
      );
      expect(exception.statusCode, 429);
      expect(exception.code, 'rate_limit');
    });

    test('auth_required error code is handled', () {
      final exception = ApiException(
        401,
        'Anmeldung erforderlich',
        code: 'auth_required',
      );
      expect(exception.statusCode, 401);
      expect(exception.code, 'auth_required');
    });

    test('forbidden error code is handled', () {
      final exception = ApiException(
        403,
        'Zugriff verweigert',
        code: 'forbidden',
      );
      expect(exception.statusCode, 403);
      expect(exception.code, 'forbidden');
    });
  });
}
