import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_url.dart';
import '../errors/app_errors.dart';
import '../invite/open_external_uri.dart';
import '../theme/app_colors.dart';

/// Public URL to open on a second phone, tablet, or browser.
String customerDisplayUrl() => '${AppUrl.publicOrigin()}/display';

/// Opens the customer-facing display in a new browser tab / window.
Future<bool> openCustomerDisplayWindow() {
  return openExternalUri(Uri.parse(customerDisplayUrl()));
}

/// Copy / open options — needed on Android & iOS where a new tab is not available.
Future<void> showCustomerDisplayOptions(BuildContext context) {
  final url = customerDisplayUrl();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Customer Display',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Open this on a second screen, tablet, or phone facing the customer. '
                'On Android or iPhone, copy the link and paste it in Chrome or Safari.',
                style: TextStyle(fontSize: 13, color: AppColors.slate600),
              ),
              const SizedBox(height: 12),
              SelectableText(
                url,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    showAppMessage(context, 'Display link copied');
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy link'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(url);
                  var opened = await openCustomerDisplayWindow();
                  if (!opened) {
                    try {
                      opened = await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {
                      opened = false;
                    }
                  }
                  if (!ctx.mounted) return;
                  if (opened) {
                    Navigator.pop(ctx);
                  } else {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      showAppMessage(
                        context,
                        'Couldn’t open the browser — link copied instead',
                      );
                    }
                  }
                },
                icon: const Icon(Icons.open_in_browser, size: 18),
                label: const Text('Open in browser'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
