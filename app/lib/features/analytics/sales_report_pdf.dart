import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/pos_models.dart';

class SalesReportData {
  const SalesReportData({
    required this.storeName,
    required this.currencySymbol,
    required this.periodLabel,
    required this.rangeLabel,
    required this.orders,
  });

  final String storeName;
  final String currencySymbol;
  final String periodLabel;
  final String rangeLabel;
  final List<PosOrder> orders;

  int get transactionCount => orders.length;
  double get grossSales => orders.fold(0.0, (s, o) => s + o.total);
  double get averageTicket => transactionCount == 0 ? 0 : grossSales / transactionCount;

  Map<PaymentMethod, double> get byPayment {
    final map = <PaymentMethod, double>{};
    for (final o in orders) {
      map[o.paymentMethod] = (map[o.paymentMethod] ?? 0) + o.total;
    }
    return map;
  }

  Map<String, double> get byCategory {
    final map = <String, double>{};
    for (final o in orders) {
      for (final i in o.items) {
        map[i.category] = (map[i.category] ?? 0) + i.unitPrice * i.qty;
      }
    }
    return map;
  }

  List<MapEntry<String, ({int qty, double sales})>> get topProducts {
    final map = <String, ({int qty, double sales})>{};
    for (final o in orders) {
      for (final i in o.items) {
        final prev = map[i.name];
        map[i.name] = (
          qty: (prev?.qty ?? 0) + i.qty,
          sales: (prev?.sales ?? 0) + i.unitPrice * i.qty,
        );
      }
    }
    final list = map.entries.toList()
      ..sort((a, b) => b.value.sales.compareTo(a.value.sales));
    return list.take(10).toList();
  }
}

Future<pw.Document> buildSalesReportPdf(SalesReportData data) async {
  final base = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final money = NumberFormat.currency(locale: 'en_PH', symbol: data.currencySymbol, decimalDigits: 2);

  final doc = pw.Document(
    title: 'Sales report — ${data.periodLabel}',
    author: 'CasinPOS',
    theme: pw.ThemeData.withFont(base: base, bold: bold),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Text('CasinPOS', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text('Owner sales report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.Text(data.storeName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.Text('${data.periodLabel} · ${data.rangeLabel}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        pw.Row(
          children: [
            _kpi('Gross sales', money.format(data.grossSales)),
            pw.SizedBox(width: 12),
            _kpi('Transactions', '${data.transactionCount}'),
            pw.SizedBox(width: 12),
            _kpi('Avg ticket', money.format(data.averageTicket)),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            _kpi(
              'VAT / tax',
              money.format(data.orders.fold<double>(0, (s, o) => s + o.tax)),
            ),
            pw.SizedBox(width: 12),
            _kpi(
              'Subtotal',
              money.format(data.orders.fold<double>(0, (s, o) => s + o.subtotal)),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text('By payment method', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        if (data.byPayment.isEmpty)
          pw.Text('No sales in this period.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
        else
          for (final e in data.byPayment.entries)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(e.key.label, style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(money.format(e.value), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
        pw.SizedBox(height: 16),
        pw.Text('By category', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        if (data.byCategory.isEmpty)
          pw.Text('No category sales.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
        else
          for (final e in (data.byCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value))))
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(e.key, style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(money.format(e.value), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
        pw.SizedBox(height: 16),
        pw.Text('Top products', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        if (data.topProducts.isEmpty)
          pw.Text('No products sold.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('Product', bold: true),
                  _cell('Qty', bold: true),
                  _cell('Sales', bold: true),
                ],
              ),
              for (final e in data.topProducts)
                pw.TableRow(
                  children: [
                    _cell(e.key),
                    _cell('${e.value.qty}'),
                    _cell(money.format(e.value.sales)),
                  ],
                ),
            ],
          ),
        pw.SizedBox(height: 24),
        pw.Text(
          'Generated ${DateFormat('MMM d, yyyy · h:mm a').format(DateTime.now())} · CasinPOS',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    ),
  );

  return doc;
}

pw.Widget _kpi(String label, String value) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label.toUpperCase(), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ),
  );
}

pw.Widget _cell(String text, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
    ),
  );
}
