import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Numeric PIN pad for 4–6 digit cashier PINs.
Future<String?> showPinPadDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  int minLength = 4,
  int maxLength = 6,
  String confirmLabel = 'Confirm',
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PinPadDialog(
      title: title,
      subtitle: subtitle,
      minLength: minLength,
      maxLength: maxLength,
      confirmLabel: confirmLabel,
    ),
  );
}

class _PinPadDialog extends StatefulWidget {
  const _PinPadDialog({
    required this.title,
    required this.minLength,
    required this.maxLength,
    required this.confirmLabel,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final int minLength;
  final int maxLength;
  final String confirmLabel;

  @override
  State<_PinPadDialog> createState() => _PinPadDialogState();
}

class _PinPadDialogState extends State<_PinPadDialog> {
  String _pin = '';

  void _tap(String digit) {
    if (_pin.length >= widget.maxLength) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += digit);
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _clear() {
    setState(() => _pin = '');
  }

  @override
  Widget build(BuildContext context) {
    final ready = _pin.length >= widget.minLength;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.subtitle != null) ...[
              Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.slate600),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.maxLength, (i) {
                final filled = i < _pin.length;
                return Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.ink : Colors.transparent,
                    border: Border.all(color: AppColors.slate400, width: 1.5),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final row in [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['C', '0', '⌫'],
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    for (final key in row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: SizedBox(
                            height: 52,
                            child: key == 'C'
                                ? OutlinedButton(
                                    onPressed: _clear,
                                    child: const Text('C'),
                                  )
                                : key == '⌫'
                                    ? OutlinedButton(
                                        onPressed: _backspace,
                                        child: const Icon(Icons.backspace_outlined, size: 18),
                                      )
                                    : FilledButton.tonal(
                                        onPressed: () => _tap(key),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.slate100,
                                          foregroundColor: AppColors.ink,
                                          textStyle: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        child: Text(key),
                                      ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: ready ? () => Navigator.pop(context, _pin) : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.slate900,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
