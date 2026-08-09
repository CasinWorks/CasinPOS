import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/pos_providers.dart';
import '../../../data/providers/session_providers.dart';
import '../../../data/repositories/cash_register_repository.dart';

class CashRegisterView extends ConsumerStatefulWidget {
  const CashRegisterView({super.key});

  @override
  ConsumerState<CashRegisterView> createState() => _CashRegisterViewState();
}

class _CashRegisterViewState extends ConsumerState<CashRegisterView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cashRegisterProvider.notifier).refresh();
    });
  }

  String _money(double v, String symbol) =>
      '$symbol${v.toStringAsFixed(2)}';

  Future<void> _openRegister(String symbol) async {
    final ctrl = TextEditingController(text: '1000');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open register'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Opening float ($symbol)',
            helperText: 'Cash counted in the drawer at start of shift',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open')),
        ],
      ),
    );
    final amount = double.tryParse(ctrl.text.trim());
    ctrl.dispose();
    if (ok != true || amount == null || amount < 0 || !mounted) return;
    try {
      await ref.read(cashRegisterProvider.notifier).open(openingFloat: amount);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: const Color(0xFFE11D48)),
      );
    }
  }

  Future<void> _movement({required bool payIn, required String symbol}) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(payIn ? 'Cash pay-in' : 'Cash pay-out'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Amount ($symbol)'),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final amount = double.tryParse(amountCtrl.text.trim());
    final note = noteCtrl.text.trim();
    amountCtrl.dispose();
    noteCtrl.dispose();
    if (ok != true || amount == null || amount <= 0 || !mounted) return;
    try {
      if (payIn) {
        await ref.read(cashRegisterProvider.notifier).payIn(amount: amount, note: note.isEmpty ? null : note);
      } else {
        await ref.read(cashRegisterProvider.notifier).payOut(amount: amount, note: note.isEmpty ? null : note);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: const Color(0xFFE11D48)),
      );
    }
  }

  Future<void> _closeRegister(RegisterBalance balance, String symbol) async {
    final ctrl = TextEditingController(
      text: balance.expectedInDrawer.toStringAsFixed(2),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close register'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Expected in drawer: ${_money(balance.expectedInDrawer, symbol)}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Actual counted cash ($symbol)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Close shift')),
        ],
      ),
    );
    final counted = double.tryParse(ctrl.text.trim());
    ctrl.dispose();
    if (ok != true || counted == null || counted < 0 || !mounted) return;
    try {
      final closed = await ref.read(cashRegisterProvider.notifier).close(closingCount: counted);
      if (!mounted) return;
      final variance = closed.variance ?? 0;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Shift closed'),
          content: Text(
            'Expected: ${_money(closed.expectedCash ?? 0, symbol)}\n'
            'Counted: ${_money(closed.closingCount ?? 0, symbol)}\n'
            'Variance: ${_money(variance, symbol)}'
            '${variance == 0 ? ' (balanced)' : variance > 0 ? ' (over)' : ' (short)'}',
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: const Color(0xFFE11D48)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbol = ref.watch(activeMembershipProvider)?.store.currencySymbol ?? '₱';
    final async = ref.watch(cashRegisterProvider);

    return ColoredBox(
      color: Colors.white,
      child: RefreshIndicator(
        onRefresh: () => ref.read(cashRegisterProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Row(
              children: [
                Icon(Icons.point_of_sale, size: 18, color: AppColors.restaurant),
                SizedBox(width: 8),
                Text('Cash register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Open a shift, track expected drawer balance, then close with a count.',
              style: TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
            const SizedBox(height: 16),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _ErrorCard(
                message: '$e',
                onRetry: () => ref.read(cashRegisterProvider.notifier).refresh(),
                hint: 'If this mentions cash_sessions, run migration 20260809000500 in Supabase SQL.',
              ),
              data: (balance) {
                if (balance == null) {
                  return _ClosedCard(
                    onOpen: () => _openRegister(symbol),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EXPECTED IN DRAWER',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _money(balance.expectedInDrawer, symbol),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Opened ${DateFormat('MMM d · h:mm a').format(balance.session.openedAt)}',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(label: 'Opening float', value: _money(balance.session.openingFloat, symbol)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile(label: 'Cash sales', value: _money(balance.cashSales, symbol)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(label: 'Pay-ins', value: _money(balance.payIns, symbol)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile(label: 'Pay-outs', value: _money(balance.payOuts, symbol)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _movement(payIn: true, symbol: symbol),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
                            icon: const Icon(Icons.add, size: 22),
                            label: const Text('Pay-in'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _movement(payIn: false, symbol: symbol),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
                            icon: const Icon(Icons.remove, size: 22),
                            label: const Text('Pay-out'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _closeRegister(balance, symbol),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.slate900,
                              minimumSize: const Size(0, 56),
                            ),
                            icon: const Icon(Icons.lock_outline, size: 22),
                            label: const Text('Close'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Recent movements', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (balance.movements.isEmpty)
                      const Text('No pay-ins or pay-outs yet.', style: TextStyle(color: AppColors.slate400, fontSize: 12))
                    else
                      for (final m in balance.movements)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            m.kind == 'pay_in' ? Icons.south_west : Icons.north_east,
                            color: m.kind == 'pay_in' ? const Color(0xFF059669) : const Color(0xFFE11D48),
                          ),
                          title: Text(
                            m.kind == 'pay_in' ? 'Pay-in' : 'Pay-out',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: Text(
                            [
                              DateFormat('h:mm a').format(m.createdAt),
                              if (m.note != null && m.note!.isNotEmpty) m.note!,
                            ].join(' · '),
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(
                            _money(m.amount, symbol),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosedCard extends StatelessWidget {
  const _ClosedCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, size: 40, color: AppColors.slate400),
          const SizedBox(height: 12),
          const Text('Register is closed', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
            'Open a shift with your starting cash float to track drawer balance.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.lock_open_rounded, size: 18),
            label: const Text('Open register'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.slate900),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.slate400)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry, this.hint});
  final String message;
  final VoidCallback onRetry;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: const TextStyle(fontSize: 12, color: Color(0xFF9F1239))),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(hint!, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
          ],
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
