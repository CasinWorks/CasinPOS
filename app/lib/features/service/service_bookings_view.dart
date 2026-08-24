import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/pos_models.dart';
import '../../../data/models/service_models.dart';
import '../../../data/providers/pos_providers.dart';
import '../../../data/providers/service_providers.dart';
import '../../../data/providers/session_providers.dart';
import '../../../domain/enums.dart';
import '../register/open_register_flow.dart';
import '../register/register_shift_banner.dart';
import 'service_schedule_sheet.dart';

class ServiceBookingsView extends ConsumerWidget {
  const ServiceBookingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serviceBookingsProvider);
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Bookings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          const RegisterShiftBanner(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(friendlyError(e))),
              data: (bookings) {
                if (bookings.isEmpty) {
                  return const Center(child: Text('No service bookings yet.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _BookingTile(booking: bookings[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingTile extends ConsumerWidget {
  const _BookingTile({required this.booking});

  final ServiceBooking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = booking.transactionId == null
        ? booking.itemsTotal
        : booking.balanceDue;
    return Material(
      color: AppColors.slate100,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.clientName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  booking.status.label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            Text(
              DateFormat.yMMMd().add_jm().format(booking.scheduledAt.toLocal()),
              style: const TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
            Text(
              booking.transactionId == null
                  ? 'No payment yet · ₱${booking.itemsTotal.toStringAsFixed(2)} due'
                  : '${booking.paymentState.label} · paid ₱${booking.amountPaid.toStringAsFixed(2)}'
                      '${due > 0 ? ' · balance ₱${due.toStringAsFixed(2)}' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
            if (booking.status == ServiceBookingStatus.upcoming)
              Wrap(
                spacing: 8,
                children: [
                  if (due > 0)
                    TextButton(
                      onPressed: () => _collect(context, ref, due),
                      child: const Text('Collect payment'),
                    ),
                  TextButton(
                    onPressed: () => _complete(context, ref, due),
                    child: const Text('Complete'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref.read(serviceRepositoryProvider).setBookingStatus(
                            bookingId: booking.id,
                            status: ServiceBookingStatus.cancelled,
                          );
                      ref.invalidate(serviceBookingsProvider);
                      ref.invalidate(serviceReportStatsProvider);
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _collect(BuildContext context, WidgetRef ref, double due) async {
    final membership = ref.read(activeMembershipProvider);
    if (membership == null) return;
    final registerOpen = await ensureCashRegisterOpenForCheckout(context, ref);
    if (!registerOpen || !context.mounted) return;
    final pay = await showCollectPaymentSheet(
      context,
      store: membership.store,
      balanceDue: due,
    );
    if (pay == null || !context.mounted) return;
    try {
      await ref.read(serviceRepositoryProvider).collectPayment(
            bookingId: booking.id,
            amount: pay.amount,
            paymentMethod: pay.method,
          );
      await refreshServiceSales(ref);
      if (pay.method == PaymentMethod.cash) {
        await ref.read(cashRegisterProvider.notifier).applyLocalCashSale(pay.amount);
      }
      if (context.mounted) showAppMessage(context, 'Payment recorded');
    } catch (e) {
      if (context.mounted) showAppError(context, friendlyError(e));
    }
  }

  Future<void> _complete(BuildContext context, WidgetRef ref, double due) async {
    if (due > 0) {
      final membership = ref.read(activeMembershipProvider);
      if (membership == null) return;
      final registerOpen = await ensureCashRegisterOpenForCheckout(context, ref);
      if (!registerOpen || !context.mounted) return;
      final pay = await showCollectPaymentSheet(
        context,
        store: membership.store,
        balanceDue: due,
      );
      if (pay == null || !context.mounted) return;
      try {
        await ref.read(serviceRepositoryProvider).collectPayment(
              bookingId: booking.id,
              amount: pay.amount,
              paymentMethod: pay.method,
            );
        if (pay.method == PaymentMethod.cash) {
          await ref.read(cashRegisterProvider.notifier).applyLocalCashSale(pay.amount);
        }
      } catch (e) {
        if (context.mounted) showAppError(context, friendlyError(e));
        return;
      }
    }
    try {
      await ref.read(serviceRepositoryProvider).setBookingStatus(
            bookingId: booking.id,
            status: ServiceBookingStatus.completed,
          );
      await refreshServiceSales(ref);
      if (context.mounted) showAppMessage(context, 'Booking completed');
    } catch (e) {
      if (context.mounted) showAppError(context, friendlyError(e));
    }
  }
}
