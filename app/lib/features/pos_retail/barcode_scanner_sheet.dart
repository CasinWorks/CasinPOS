import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/errors/app_errors.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/pos_models.dart';
import '../../data/providers/pos_providers.dart';

/// Tablet camera barcode → add matching catalog product to cart.
Future<void> openBarcodeScanner(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    builder: (ctx) => const _BarcodeScannerSheet(),
  );
}

class _BarcodeScannerSheet extends ConsumerStatefulWidget {
  const _BarcodeScannerSheet();

  @override
  ConsumerState<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends ConsumerState<_BarcodeScannerSheet> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  var _locked = false;
  String? _lastCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_locked) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue?.trim())
        .whereType<String>()
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (raw.isEmpty || raw == _lastCode) return;
    _locked = true;
    _lastCode = raw;

    final products = ref.read(posCatalogProvider);
    RetailProduct? match;
    for (final p in products) {
      if (p.barcode == raw || p.sku == raw) {
        match = p;
        break;
      }
    }

    if (!mounted) return;
    if (match == null) {
      showAppMessage(context, 'No product for code $raw', isError: true);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      _locked = false;
      return;
    }

    try {
      ref.read(cartProvider.notifier).add(match);
      if (!mounted) return;
      showAppMessage(context, 'Added ${match.name}');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showAppError(context, e, fallback: 'Could not add item');
      _locked = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                const Expanded(
                  child: Text(
                    'Scan barcode / SKU',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _controller.toggleTorch(),
                  icon: const Icon(Icons.flash_on, color: Colors.white),
                ),
              ],
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.15),
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 28,
            left: 24,
            right: 24,
            child: Text(
              'Point at a product barcode. Matching catalog items are added to the cart.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
