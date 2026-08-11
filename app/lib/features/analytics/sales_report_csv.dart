import 'package:intl/intl.dart';

import '../../data/models/pos_models.dart';
import 'sales_report_pdf.dart';

/// Builds CSV text for sales + a VAT summary block.
String buildSalesReportCsv(SalesReportData data) {
  final buf = StringBuffer();
  final money = NumberFormat('0.00');

  buf.writeln('CasinPOS sales export');
  buf.writeln(_csvRow(['Store', data.storeName]));
  buf.writeln(_csvRow(['Period', data.periodLabel]));
  buf.writeln(_csvRow(['Range', data.rangeLabel]));
  buf.writeln('');

  final taxTotal = data.orders.fold<double>(0, (s, o) => s + o.tax);
  final subtotal = data.orders.fold<double>(0, (s, o) => s + o.subtotal);
  final gross = data.grossSales;

  buf.writeln('SUMMARY');
  buf.writeln(_csvRow(['Transactions', '${data.transactionCount}']));
  buf.writeln(_csvRow(['Gross sales', money.format(gross)]));
  buf.writeln(_csvRow(['Subtotal', money.format(subtotal)]));
  buf.writeln(_csvRow(['VAT / tax collected', money.format(taxTotal)]));
  buf.writeln(_csvRow(['Average ticket', money.format(data.averageTicket)]));
  buf.writeln('');

  buf.writeln('BY PAYMENT');
  buf.writeln(_csvRow(['Method', 'Amount']));
  for (final e in data.byPayment.entries) {
    buf.writeln(_csvRow([e.key.label, money.format(e.value)]));
  }
  buf.writeln('');

  buf.writeln('TRANSACTIONS');
  buf.writeln(_csvRow([
    'Date',
    'Time',
    'Order ID',
    'Payment',
    'Subtotal',
    'Tax',
    'Total',
    'Items',
  ]));
  final sorted = [...data.orders]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  for (final o in sorted) {
    final items = o.items.map((i) => '${i.qty}× ${i.name}').join('; ');
    buf.writeln(_csvRow([
      DateFormat('yyyy-MM-dd').format(o.createdAt),
      DateFormat('HH:mm').format(o.createdAt),
      o.id,
      o.paymentMethod.label,
      money.format(o.subtotal),
      money.format(o.tax),
      money.format(o.total),
      items,
    ]));
  }
  buf.writeln('');

  buf.writeln('LINE ITEMS');
  buf.writeln(_csvRow([
    'Date',
    'Order ID',
    'Product',
    'Category',
    'Qty',
    'Unit price',
    'Line total',
  ]));
  for (final o in sorted) {
    for (final i in o.items) {
      buf.writeln(_csvRow([
        DateFormat('yyyy-MM-dd').format(o.createdAt),
        o.id,
        i.name,
        i.category,
        '${i.qty}',
        money.format(i.unitPrice),
        money.format(i.unitPrice * i.qty),
      ]));
    }
  }

  return buf.toString();
}

String _csvRow(List<String> cells) => cells.map(_csvEscape).join(',');

String _csvEscape(String value) {
  final needsQuotes =
      value.contains(',') || value.contains('"') || value.contains('\n');
  final escaped = value.replaceAll('"', '""');
  return needsQuotes ? '"$escaped"' : escaped;
}
