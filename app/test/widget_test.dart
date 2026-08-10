import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:casinpos/core/theme/app_theme.dart';
import 'package:casinpos/features/onboarding/story_mode.dart';
import 'package:casinpos/features/shell/pos_shell_page.dart';

void main() {
  testWidgets('Retail POS shell renders CasinPOS branding', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tutorialCompletedProvider.overrideWith((ref) => true),
          storyModeActiveProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PosShellPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Food'), findsWidgets);
    expect(find.textContaining('Retail POS'), findsWidgets);
  });
}
