import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/pos_models.dart';
import '../../../data/models/store_models.dart';
import 'client_picker_fields.dart';

class ServiceScheduleResult {
  const ServiceScheduleResult({
    required this.scheduledAt,
    required this.depositAmount,
    this.paymentMethod,
    this.clientName,
    this.clientPhone,
  });

  final DateTime scheduledAt;
  final double depositAmount;
  final PaymentMethod? paymentMethod;
  final String? clientName;
  final String? clientPhone;
}

Future<ServiceScheduleResult?> showServiceScheduleSheet(
  BuildContext context, {
  required StoreSummary store,
  required double jobTotal,
  String title = 'Schedule booking',
  bool askClient = false,
  String? initialClientName,
  String? initialClientPhone,
}) {
  return showModalBottomSheet<ServiceScheduleResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ScheduleSheet(
      store: store,
      jobTotal: jobTotal,
      title: title,
      askClient: askClient,
      initialClientName: initialClientName,
      initialClientPhone: initialClientPhone,
    ),
  );
}

class _ScheduleSheet extends ConsumerStatefulWidget {
  const _ScheduleSheet({
    required this.store,
    required this.jobTotal,
    required this.title,
    required this.askClient,
    this.initialClientName,
    this.initialClientPhone,
  });

  final StoreSummary store;
  final double jobTotal;
  final String title;
  final bool askClient;
  final String? initialClientName;
  final String? initialClientPhone;

  @override
  ConsumerState<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends ConsumerState<_ScheduleSheet> {
  late DateTime _date;
  late TimeOfDay _time;
  final _deposit = TextEditingController();
  final _clientName = TextEditingController();
  final _clientPhone = TextEditingController();
  PaymentMethod? _method;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().add(const Duration(hours: 1));
    _date = DateTime(now.year, now.month, now.day);
    _time = TimeOfDay(hour: now.hour, minute: 0);
    _clientName.text = widget.initialClientName ?? '';
    _clientPhone.text = widget.initialClientPhone ?? '';
    final methods = widget.store.enabledPaymentMethods;
    _method = methods.isNotEmpty ? methods.first : PaymentMethod.cash;
  }

  @override
  void dispose() {
    _deposit.dispose();
    _clientName.dispose();
    _clientPhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewInsetsOf(context).bottom;
    final symbol = widget.store.currencySymbol;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + pad),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              'Accept always creates a booking. Deposit is optional.',
              style: TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
            if (widget.askClient) ...[
              const SizedBox(height: 12),
              ClientPickerFields(name: _clientName, phone: _clientPhone),
            ],
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Time'),
              subtitle: Text(_time.format(context)),
              trailing: const Icon(Icons.schedule_outlined),
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: _time);
                if (picked != null) setState(() => _time = picked);
              },
            ),
            TextField(
              controller: _deposit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Deposit (optional)',
                hintText: '0 = collect later',
                prefixText: symbol,
                helperText: 'Job total $symbol${widget.jobTotal.toStringAsFixed(2)}',
              ),
            ),
            const SizedBox(height: 8),
            Text('Payment method (if deposit)', style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: 8,
              children: [
                for (final m in widget.store.enabledPaymentMethods)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: _method == m,
                    onSelected: (_) => setState(() => _method = m),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (widget.askClient && _clientName.text.trim().isEmpty) {
                  setState(() => _error = 'Client name is required.');
                  return;
                }
                final deposit = double.tryParse(_deposit.text.trim().replaceAll(',', '')) ?? 0;
                if (deposit < 0) {
                  setState(() => _error = 'Deposit can’t be negative.');
                  return;
                }
                if (deposit > 0 && _method == null) {
                  setState(() => _error = 'Choose how the deposit was paid.');
                  return;
                }
                final scheduled = DateTime(
                  _date.year,
                  _date.month,
                  _date.day,
                  _time.hour,
                  _time.minute,
                );
                Navigator.pop(
                  context,
                  ServiceScheduleResult(
                    scheduledAt: scheduled,
                    depositAmount: deposit,
                    paymentMethod: deposit > 0 ? _method : null,
                    clientName: _clientName.text.trim(),
                    clientPhone: _clientPhone.text.trim(),
                  ),
                );
              },
              child: const Text('Create booking'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<({double amount, PaymentMethod method})?> showCollectPaymentSheet(
  BuildContext context, {
  required StoreSummary store,
  required double balanceDue,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _CollectSheet(store: store, balanceDue: balanceDue),
  );
}

class _CollectSheet extends StatefulWidget {
  const _CollectSheet({required this.store, required this.balanceDue});

  final StoreSummary store;
  final double balanceDue;

  @override
  State<_CollectSheet> createState() => _CollectSheetState();
}

class _CollectSheetState extends State<_CollectSheet> {
  late final TextEditingController _amount;
  PaymentMethod? _method;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.balanceDue.toStringAsFixed(2));
    _method = widget.store.enabledPaymentMethods.first;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + pad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Collect payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: widget.store.currencySymbol,
              helperText: 'Balance due ${widget.store.currencySymbol}${widget.balanceDue.toStringAsFixed(2)}',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in widget.store.enabledPaymentMethods)
                ChoiceChip(
                  label: Text(m.label),
                  selected: _method == m,
                  onSelected: (_) => setState(() => _method = m),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;
              if (amt <= 0 || _method == null) return;
              Navigator.pop(context, (amount: amt, method: _method!));
            },
            child: const Text('Record payment'),
          ),
        ],
      ),
    );
  }
}
