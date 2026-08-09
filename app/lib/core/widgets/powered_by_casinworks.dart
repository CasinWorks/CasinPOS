import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

/// Subtle “Powered by CASINWORKS” credit; opens the company site in a new tab on web.
class PoweredByCasinworks extends StatelessWidget {
  const PoweredByCasinworks({super.key});

  static final Uri uri = Uri.parse('https://www.casinworks.com');

  static Future<void> openSite() async {
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: 'Powered by CASINWORKS',
      button: true,
      child: InkWell(
        onTap: openSite,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Center(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate400,
                  ),
                  children: [
                    TextSpan(text: 'Powered by '),
                    TextSpan(
                      text: 'CASINWORKS',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.35,
                        color: AppColors.slate500,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.slate300,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
