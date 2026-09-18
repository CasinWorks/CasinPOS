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
  bool _loading = false;
  String? _error;
  BusinessType _type = BusinessType.retail;
  ServicePricingMode _pricingMode = ServicePricingMode.fixed;

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
            servicePricingMode:
                _type == BusinessType.service ? _pricingMode : null,
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandLogo(size: 112, radius: 22, shadow: true)),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Create your store',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Retail checkout with inventory, or a service business with bookings and optional quotes. Restaurant mode is coming later.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Store name',
                      hintText: 'e.g. Cascade Mini Mart',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Store name is required' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Business type', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<BusinessType>(
                    segments: const [
                      ButtonSegment(
                        value: BusinessType.retail,
                        label: Text('Retail'),
                        icon: Icon(Icons.storefront_rounded, size: 18),
                      ),
                      ButtonSegment(
                        value: BusinessType.service,
                        label: Text('Service'),
                        icon: Icon(Icons.handyman_rounded, size: 18),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() => _type = s.first),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_type == BusinessType.service) ...[
                    Text('How you price work', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<ServicePricingMode>(
                      segments: const [
                        ButtonSegment(
                          value: ServicePricingMode.fixed,
                          label: Text('Fixed price'),
                        ),
                        ButtonSegment(
                          value: ServicePricingMode.quote,
                          label: Text('Quotes'),
                        ),
                      ],
                      selected: {_pricingMode},
                      onSelectionChanged: (s) => setState(() => _pricingMode = s.first),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _pricingMode == ServicePricingMode.quote
                          ? 'Send quotes, then accept to create a booking. Deposit is optional.'
                          : 'Catalog of services with prices. Checkout books a date/time; deposit is optional.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.slate500,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.retailDark.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.storefront_rounded, color: AppColors.retailDark),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Retail POS',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'SKU catalog, inventory, and checkout',
                                  style: TextStyle(fontSize: 12, color: AppColors.slate500),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                      try {
                        await ref.read(authRepositoryProvider).signOut();
                      } catch (_) {}
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
      ),
    );
  }
}
