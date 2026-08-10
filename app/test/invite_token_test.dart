import 'package:flutter_test/flutter_test.dart';

import 'package:casinpos/core/invite/invite_token.dart';

void main() {
  group('sanitizeInviteToken', () {
    test('extracts token from full invite URL', () {
      expect(
        sanitizeInviteToken(
          'https://casin-pos-black.vercel.app/invite?token=abc12345',
        ),
        'abc12345',
      );
    });

    test('rejects bare /invite without token', () {
      expect(
        sanitizeInviteToken('https://casin-pos-black.vercel.app/invite'),
        isNull,
      );
      expect(
        isInviteUrlMissingToken('https://casin-pos-black.vercel.app/invite'),
        isTrue,
      );
    });

    test('rejects bare /join without token', () {
      expect(
        sanitizeInviteToken('https://casin-pos-black.vercel.app/join'),
        isNull,
      );
      expect(isInviteUrlMissingToken('/join'), isTrue);
    });

    test('extracts path-form /invite/:token', () {
      expect(
        sanitizeInviteToken('https://casin-pos-black.vercel.app/invite/tok_xyz9'),
        'tok_xyz9',
      );
    });
  });
}
