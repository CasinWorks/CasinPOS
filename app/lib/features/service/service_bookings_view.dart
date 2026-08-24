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

enum _BookingsLayout { calendar, list }

class ServiceBookingsView extends ConsumerStatefulWidget {
  const ServiceBookingsView({super.key});

  @override
  ConsumerState<ServiceBookingsView> createState() => _ServiceBookingsViewState();
}

class _ServiceBookingsViewState extends ConsumerState<ServiceBookingsView> {
  _BookingsLayout _layout = _BookingsLayout.calendar;
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(serviceBookingsProvider);
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bookings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                SegmentedButton<_BookingsLayout>(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: _BookingsLayout.calendar,
                      label: Text('Calendar'),
                      icon: Icon(Icons.calendar_month_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: _BookingsLayout.list,
                      label: Text('List'),
                      icon: Icon(Icons.view_list_outlined, size: 16),
                    ),
                  ],
                  selected: {_layout},
                  onSelectionChanged: (s) => setState(() => _layout = s.first),
                ),
              ],
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
                if (_layout == _BookingsLayout.list) {
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: bookings.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _BookingTile(booking: bookings[i]),
                  );
                }
                return _CalendarBookingsBody(
                  bookings: bookings,
                  visibleMonth: _visibleMonth,
                  selectedDay: _selectedDay,
                  onMonthChanged: (m) => setState(() => _visibleMonth = m),
                  onDaySelected: (d) => setState(() {
                    _selectedDay = d;
                    _visibleMonth = DateTime(d.year, d.month);
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarBookingsBody extends StatelessWidget {
  const _CalendarBookingsBody({
    required this.bookings,
    required this.visibleMonth,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  final List<ServiceBooking> bookings;
  final DateTime visibleMonth;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  static DateTime dayKey(DateTime d) {
    final l = d.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  Map<DateTime, List<ServiceBooking>> get _byDay {
    final map = <DateTime, List<ServiceBooking>>{};
    for (final b in bookings) {
      final k = dayKey(b.scheduledAt);
      (map[k] ??= []).add(b);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _byDay;
    final dayJobs = grouped[selectedDay] ?? const <ServiceBooking>[];
    final dayLabel = DateFormat.yMMMMEEEEd().format(selectedDay);

    final calendar = _MonthCalendar(
      month: visibleMonth,
      selectedDay: selectedDay,
      bookingsByDay: grouped,
      onMonthChanged: onMonthChanged,
      onDaySelected: onDaySelected,
    );

    final dayList = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            '${dayJobs.length} ${dayJobs.length == 1 ? 'job' : 'jobs'} · $dayLabel',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.slate700,
            ),
          ),
        ),
        Expanded(
          child: dayJobs.isEmpty
              ? const Center(child: Text('No jobs on this day.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: dayJobs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _BookingTile(booking: dayJobs[i]),
                ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 400, child: calendar),
              const VerticalDivider(width: 1),
              Expanded(child: dayList),
            ],
          );
        }
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: calendar),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  '${dayJobs.length} ${dayJobs.length == 1 ? 'job' : 'jobs'} · $dayLabel',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate700,
                  ),
                ),
              ),
            ),
            if (dayJobs.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('No jobs on this day.')),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList.separated(
                  itemCount: dayJobs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _BookingTile(booking: dayJobs[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selectedDay,
    required this.bookingsByDay,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  final DateTime month;
  final DateTime selectedDay;
  final Map<DateTime, List<ServiceBooking>> bookingsByDay;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday % 7; // Sunday start
    final today = _CalendarBookingsBody.dayKey(DateTime.now());
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => onMonthChanged(DateTime(month.year, month.month - 1)),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM().format(month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              TextButton(
                onPressed: () => onDaySelected(today),
                child: const Text('Today'),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => onMonthChanged(DateTime(month.year, month.month + 1)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              for (final label in labels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ((leading + daysInMonth + 6) ~/ 7) * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, i) {
              final dayNum = i - leading + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox.shrink();
              }
              final day = DateTime(month.year, month.month, dayNum);
              final jobs = bookingsByDay[day] ?? const <ServiceBooking>[];
              final selected = day == selectedDay;
              final isToday = day == today;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onDaySelected(day),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isToday && !selected
                        ? Border.all(color: AppColors.accentDeep)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: selected ? AppColors.ink : AppColors.slate800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        height: 6,
                        child: jobs.isEmpty
                            ? const SizedBox.shrink()
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final b in jobs.take(3))
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 1),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppColors.ink
                                              : _dotColor(b.status),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const SizedBox(width: 5, height: 5),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static Color _dotColor(ServiceBookingStatus status) {
    return switch (status) {
      ServiceBookingStatus.upcoming => AppColors.accentDeep,
      ServiceBookingStatus.completed => AppColors.success,
      ServiceBookingStatus.cancelled => AppColors.slate400,
    };
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
