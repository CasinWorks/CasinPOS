import 'package:flutter_test/flutter_test.dart';

import 'package:casinpos/core/invite/invite_token.dart';

void main() {
  group('sanitizeInviteToken', () {
    test('extracts token from full invite URL', () {
      expect(
        sanitizeInviteToken(
          'https://pos.casinworks.com/invite?token=abc12345',
        ),
        'abc12345',
      );
    });

    test('rejects bare /invite without token', () {
      expect(
        sanitizeInviteToken('https://pos.casinworks.com/invite'),
        isNull,
      );
      expect(
        isInviteUrlMissingToken('https://pos.casinworks.com/invite'),
        isTrue,
      );
    });

    test('rejects bare /join without token', () {
      expect(
        sanitizeInviteToken('https://pos.casinworks.com/join'),
        isNull,
      );
      expect(isInviteUrlMissingToken('/join'), isTrue);
    });

    test('extracts path-form /invite/:token', () {
      expect(
        sanitizeInviteToken('https://pos.casinworks.com/invite/tok_xyz9'),
        'tok_xyz9',
      );
    });
  });
}
