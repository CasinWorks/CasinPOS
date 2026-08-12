/// Public support contact for CasinPOS (App Store / in-app Support).
abstract final class SupportContact {
  static const email = 'christianjoshuacasin@gmail.com';
  static const displayName = 'CasinPOS Support';

  static Uri mailto({
    String subject = 'CasinPOS support',
    String? body,
  }) {
    return Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': subject,
        if (body != null && body.trim().isNotEmpty) 'body': body,
      },
    );
  }
}
