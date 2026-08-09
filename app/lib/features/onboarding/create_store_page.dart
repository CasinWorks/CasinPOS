import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/powered_by_casinworks.dart';
import '../../../data/providers/session_providers.dart';
import '../../../domain/enums.dart';

class CreateStorePage extends ConsumerStatefulWidget {
  const CreateStorePage({super.key});

  @override
  ConsumerState<CreateStorePage> createState() => _CreateStorePageState();
}

class _CreateStorePageState extends ConsumerState<CreateStorePage> {
  final _name = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  BusinessType _type = BusinessType.retail;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(storeRepositoryProvider).createStore(
            name: _name.text,
            businessType: _type,
            currencyCode: AppConstants.defaultCurrencyCode,
            currencySymbol: AppConstants.defaultCurrencySymbol,
          );
      await ref.read(storeRepositoryProvider).markOnboardingComplete();
      ref.invalidate(membershipsProvider);
      if (mounted) context.go('/');
    } catch (e) {
      final msg = friendlyError(e, fallback: 'Could not create store. Please try again.');
      setState(() => _error = msg);
      if (mounted) showAppError(context, msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BrandMark(businessType: _type),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Create your store',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Just two things to start. Business type is permanent — pick carefully.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Store name',
                      hintText: 'e.g. Cascade Café',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Store name is required' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Business type (cannot change later)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeCard(
                          title: 'Retail',
                          subtitle: 'SKU catalog, inventory, POS',
                          selected: _type == BusinessType.retail,
                          accent: AppColors.retailDark,
                          icon: Icons.storefront_rounded,
                          onTap: () => setState(() => _type = BusinessType.retail),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _TypeCard(
                          title: 'Restaurant / Food',
                          subtitle: 'Menu, floor plan, bookings',
                          selected: _type == BusinessType.restaurant,
                          accent: AppColors.restaurant,
                          icon: Icons.restaurant_menu_rounded,
                          onTap: () => setState(() => _type = BusinessType.restaurant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      'This choice is permanent. Retail cannot become Restaurant later (and the reverse).',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Currency defaults to ${AppConstants.defaultCurrencyCode} '
                    '(${AppConstants.defaultCurrencySymbol}). Change later in settings.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.slate400,
                        ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create store & continue'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/invite'),
                    child: const Text('I was invited to an existing store'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) context.go('/login');
                    },
                    child: const Text('Sign out'),
                  ),
                  const PoweredByCasinworks(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent.withValues(alpha: 0.08) : AppColors.scaffold,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(
              color: selected ? accent : AppColors.slate200,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent),
              const SizedBox(height: AppSpacing.sm),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
