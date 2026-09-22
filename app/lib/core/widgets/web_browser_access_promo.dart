import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_url.dart';
import '../errors/app_errors.dart';
import '../theme/app_colors.dart';

/// Promotes opening CasinPOS in the browser at pos.casinworks.com.
/// Hidden on web (already in the browser).
class WebBrowserAccessPromo extends StatelessWidget {
  const WebBrowserAccessPromo({
    super.key,
    this.compact = false,
    this.margin,
  });

  final bool compact;
  final EdgeInsetsGeometry? margin;

  static String get displayHost {
    final host = Uri.tryParse(AppUrl.defaultProduction)?.host;
    return host ?? 'pos.casinworks.com';
  }

  static Uri get webUri => Uri.parse(AppUrl.defaultProduction);

  static Future<void> openWebApp() async {
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  static Future<void> copyWebLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: AppUrl.defaultProduction));
    if (context.mounted) {
      showAppMessage(context, 'Link copied — $displayHost');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();

    if (compact) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: Material(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: openWebApp,
            onLongPress: () => copyWebLink(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.language_rounded, size: 18, color: AppColors.ink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Open in browser',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          displayHost,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.slate600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy link',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => copyWebLink(context),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.brandYellow.withValues(alpha: 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.language_rounded, size: 20, color: AppColors.ink),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Also use CasinPOS in your browser',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Sell from a laptop or another device at $displayHost — same account.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.slate600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: openWebApp,
                    child: const Text('Open website'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => copyWebLink(context),
                  child: const Text('Copy'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
