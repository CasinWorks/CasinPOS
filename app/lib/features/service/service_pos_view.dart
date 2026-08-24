import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/service_models.dart';
import '../../../data/models/pos_models.dart';
import '../../../data/providers/pos_providers.dart';
import '../../../data/providers/service_providers.dart';
import '../../../data/providers/session_providers.dart';
import '../register/open_register_flow.dart';
import '../register/register_shift_banner.dart';
import 'service_schedule_sheet.dart';

class ServicePosView extends ConsumerStatefulWidget {
  const ServicePosView({super.key});

  @override
  ConsumerState<ServicePosView> createState() => _ServicePosViewState();
}

class _ServicePosViewState extends ConsumerState<ServicePosView> {
  final _qty = <String, int>{};

  double _total(List<ServiceOffering> catalog) {
    var t = 0.0;
    for (final s in catalog.where((e) => e.isActive)) {
      final q = _qty[s.id] ?? 0;
      t += q * s.price;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(serviceCatalogProvider);
    return ColoredBox(
      color: Colors.white,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (catalog) {
          final active = catalog.where((s) => s.isActive).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Service POS',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Pick services, then book a date/time. Deposit is optional.',
                  style: TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
              ),
              const RegisterShiftBanner(),
              Expanded(
                child: active.isEmpty
                    ? const Center(child: Text('Add services in the Services tab first.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: active.length,
                        itemBuilder: (context, i) {
                          final s = active[i];
                          final q = _qty[s.id] ?? 0;
                          return ListTile(
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${s.durationMinutes} min · ₱${s.price.toStringAsFixed(0)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: q <= 0
                                      ? null
                                      : () => setState(() => _qty[s.id] = q - 1),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text('$q', style: const TextStyle(fontWeight: FontWeight.w800)),
                                IconButton(
                                  onPressed: () => setState(() => _qty[s.id] = q + 1),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: _total(active) <= 0 ? null : () => _book(active),
                    child: Text('Book · ₱${_total(active).toStringAsFixed(0)}'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _book(List<ServiceOffering> catalog) async {
    final membership = ref.read(activeMembershipProvider);
    if (membership == null) return;
    final items = <Map<String, dynamic>>[];
    for (final s in catalog) {
      final q = _qty[s.id] ?? 0;
      if (q <= 0) continue;
      items.add({
        'service_id': s.id,
        'description': s.name,
        'quantity': q,
        'unit_price': s.price,
      });
    }
    if (items.isEmpty) return;
    final registerOpen = await ensureCashRegisterOpenForCheckout(context, ref);
    if (!registerOpen || !mounted) return;
    final result = await showServiceScheduleSheet(
      context,
      store: membership.store,
      jobTotal: _total(catalog),
      title: 'Book services',
      askClient: true,
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(serviceRepositoryProvider).createCatalogBooking(
            storeId: membership.storeId,
            clientName: result.clientName ?? '',
            clientPhone: result.clientPhone,
            scheduledAt: result.scheduledAt,
            items: items,
            depositAmount: result.depositAmount,
            paymentMethod: result.paymentMethod,
          );
      await refreshServiceSales(ref);
      if (!mounted) return;
      setState(() => _qty.clear());
      if (result.depositAmount > 0 && result.paymentMethod == PaymentMethod.cash) {
        await ref
            .read(cashRegisterProvider.notifier)
            .applyLocalCashSale(result.depositAmount);
      }
      if (!mounted) return;
      showAppMessage(context, 'Booking created');
    } catch (e) {
      if (mounted) showAppError(context, friendlyError(e));
    }
  }
}
