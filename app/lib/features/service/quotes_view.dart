import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'client_picker_fields.dart';
import 'service_schedule_sheet.dart';

class QuotesView extends ConsumerWidget {
  const QuotesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serviceQuotesProvider);
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
                    'Quotes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _edit(context, ref, null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New quote'),
                ),
              ],
            ),
          ),
          const RegisterShiftBanner(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(friendlyError(e))),
              data: (quotes) {
                if (quotes.isEmpty) {
                  return const Center(child: Text('No quotes yet.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: quotes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _QuoteTile(quote: quotes[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _edit(BuildContext context, WidgetRef ref, ServiceQuote? existing) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _QuoteEditorDialog(existing: existing),
  );
  if (saved == true) {
    ref.invalidate(serviceQuotesProvider);
    ref.invalidate(serviceCustomersProvider);
  }
}

class _QuoteTile extends ConsumerWidget {
  const _QuoteTile({required this.quote});

  final ServiceQuote quote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expired = quote.isExpired;
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
                    quote.clientName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusChip(status: quote.status, expired: expired),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '₱${quote.estimatedTotal.toStringAsFixed(2)}'
              '${quote.validUntil != null ? ' · valid ${DateFormat.yMMMd().format(quote.validUntil!)}' : ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
            if (expired)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Expired — edit and re-send. Status stays Sent so you can revive it.',
                  style: TextStyle(fontSize: 11, color: AppColors.warning),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (quote.status == QuoteStatus.draft || quote.status == QuoteStatus.sent)
                  TextButton(
                    onPressed: () => _edit(context, ref, quote),
                    child: const Text('Edit'),
                  ),
                if (quote.status == QuoteStatus.draft || quote.status == QuoteStatus.sent)
                  TextButton(
                    onPressed: () async {
                      try {
                        await ref.read(serviceRepositoryProvider).sendQuote(quote.id);
                        ref.invalidate(serviceQuotesProvider);
                        if (context.mounted) showAppMessage(context, 'Quote marked sent');
                      } catch (e) {
                        if (context.mounted) showAppError(context, friendlyError(e));
                      }
                    },
                    child: const Text('Send'),
                  ),
                if (quote.status == QuoteStatus.sent || quote.status == QuoteStatus.draft)
                  TextButton(
                    onPressed: () => _accept(context, ref, quote),
                    child: const Text('Accept'),
                  ),
                if (quote.status == QuoteStatus.sent)
                  TextButton(
                    onPressed: () async {
                      await ref.read(serviceRepositoryProvider).rejectQuote(quote.id);
                      ref.invalidate(serviceQuotesProvider);
                    },
                    child: const Text('Reject'),
                  ),
                if (quote.shareToken != null)
                  TextButton(
                    onPressed: () async {
                      final text = _shareText(quote);
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) {
                        showAppMessage(context, 'Quote summary copied');
                      }
                    },
                    child: const Text('Copy share'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref, ServiceQuote quote) async {
    final membership = ref.read(activeMembershipProvider);
    if (membership == null) return;
    final result = await showServiceScheduleSheet(
      context,
      store: membership.store,
      jobTotal: quote.estimatedTotal,
      title: 'Accept quote',
    );
    if (result == null || !context.mounted) return;
    if (result.depositAmount > 0) {
      final registerOpen = await ensureCashRegisterOpenForCheckout(context, ref);
      if (!registerOpen || !context.mounted) return;
    }
    try {
      await ref.read(serviceRepositoryProvider).acceptQuote(
            quoteId: quote.id,
            scheduledAt: result.scheduledAt,
            depositAmount: result.depositAmount,
            paymentMethod: result.paymentMethod,
          );
      await refreshServiceSales(ref);
      if (result.depositAmount > 0 && result.paymentMethod == PaymentMethod.cash) {
        await ref
            .read(cashRegisterProvider.notifier)
            .applyLocalCashSale(result.depositAmount);
      }
      if (context.mounted) showAppMessage(context, 'Booking created from quote');
    } catch (e) {
      if (context.mounted) showAppError(context, friendlyError(e));
    }
  }
}

String _shareText(ServiceQuote quote) {
  final buf = StringBuffer()
    ..writeln('Quote for ${quote.clientName}')
    ..writeln('Total: ₱${quote.estimatedTotal.toStringAsFixed(2)}');
  if (quote.validUntil != null) {
    buf.writeln('Valid until: ${DateFormat.yMMMd().format(quote.validUntil!)}');
  }
  if (quote.jobDescription != null && quote.jobDescription!.trim().isNotEmpty) {
    buf.writeln(quote.jobDescription!.trim());
  }
  for (final line in quote.lines) {
    buf.writeln(
      '• ${line.description} × ${line.quantity} @ ₱${line.unitPrice.toStringAsFixed(2)}',
    );
  }
  if (quote.shareToken != null) {
    buf.writeln('Ref: ${quote.shareToken}');
  }
  return buf.toString();
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.expired});

  final QuoteStatus status;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final label = expired && (status == QuoteStatus.sent || status == QuoteStatus.draft)
        ? '${status.label} · expired'
        : status.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _QuoteEditorDialog extends ConsumerStatefulWidget {
  const _QuoteEditorDialog({this.existing});

  final ServiceQuote? existing;

  @override
  ConsumerState<_QuoteEditorDialog> createState() => _QuoteEditorDialogState();
}

class _QuoteEditorDialogState extends ConsumerState<_QuoteEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _job;
  late final List<QuoteLineDraft> _lines;
  DateTime? _validUntil;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.clientName ?? '');
    _phone = TextEditingController(text: e?.clientPhone ?? '');
    _email = TextEditingController(text: e?.clientEmail ?? '');
    _job = TextEditingController(text: e?.jobDescription ?? '');
    _validUntil = e?.validUntil;
    _lines = e == null || e.lines.isEmpty
        ? [QuoteLineDraft()]
        : [
            for (final l in e.lines)
              QuoteLineDraft(
                description: l.description,
                quantity: l.quantity,
                unitPrice: l.unitPrice,
              ),
          ];
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _job.dispose();
    super.dispose();
  }

  double get _total => _lines.fold(0, (s, l) => s + l.lineTotal);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New quote' : 'Edit quote'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClientPickerFields(name: _name, phone: _phone, email: _email),
              TextField(
                controller: _job,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Job description'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Valid until'),
                subtitle: Text(
                  _validUntil == null ? 'Default +14 days on send' : DateFormat.yMMMd().format(_validUntil!),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _validUntil ?? DateTime.now().add(const Duration(days: 14)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _validUntil = picked);
                },
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Line items', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              for (var i = 0; i < _lines.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          initialValue: _lines[i].description,
                          decoration: const InputDecoration(labelText: 'Description'),
                          onChanged: (v) => _lines[i].description = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: _lines[i].quantity.toString(),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Qty'),
                          onChanged: (v) {
                            _lines[i].quantity = double.tryParse(v) ?? 1;
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: _lines[i].unitPrice.toString(),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Price'),
                          onChanged: (v) {
                            _lines[i].unitPrice = double.tryParse(v.replaceAll(',', '')) ?? 0;
                            setState(() {});
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: _lines.length == 1
                            ? null
                            : () => setState(() => _lines.removeAt(i)),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                onPressed: () => setState(() => _lines.add(QuoteLineDraft())),
                icon: const Icon(Icons.add),
                label: const Text('Add line'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total ₱${_total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  final membership = ref.read(activeMembershipProvider);
                  final uid = ref.read(authRepositoryProvider).currentUser?.id;
                  if (membership == null || uid == null) return;
                  if (_name.text.trim().isEmpty) return;
                  setState(() => _saving = true);
                  try {
                    final branchId = await ref
                        .read(serviceRepositoryProvider)
                        .primaryBranchId(membership.storeId);
                    await ref.read(serviceRepositoryProvider).saveQuote(
                          storeId: membership.storeId,
                          branchId: branchId,
                          createdBy: uid,
                          id: widget.existing?.id,
                          clientName: _name.text,
                          clientPhone: _phone.text,
                          clientEmail: _email.text,
                          jobDescription: _job.text,
                          validUntil: _validUntil,
                          lines: _lines
                              .where((l) => l.description.trim().isNotEmpty)
                              .toList(),
                          status: widget.existing?.status == QuoteStatus.sent
                              ? QuoteStatus.draft
                              : (widget.existing?.status ?? QuoteStatus.draft),
                        );
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (context.mounted) showAppError(context, friendlyError(e));
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: const Text('Save draft'),
        ),
      ],
    );
  }
}
