import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/pos_models.dart';

class ReceiptPdfContext {
  const ReceiptPdfContext({
    required this.storeName,
    required this.currencySymbol,
    this.cashierName,
    this.businessTypeLabel = 'Retail',
  });

  final String storeName;
  final String currencySymbol;
  final String? cashierName;
  final String businessTypeLabel;
}

Future<pw.Document> buildReceiptPdf({
  required PosOrder order,
  required ReceiptPdfContext context,
}) async {
  // Helvetica cannot render ₱ — use Noto Sans (Unicode).
  final base = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final italic = await PdfGoogleFonts.notoSansItalic();

  final doc = pw.Document(
    title: 'Receipt ${order.orderNo}',
    author: 'CasinPOS',
    theme: pw.ThemeData.withFont(
      base: base,
      bold: bold,
      italic: italic,
      boldItalic: bold,
    ),
  );

  final money = NumberFormat.currency(
    locale: 'en_PH',
    symbol: _pdfCurrencySymbol(context.currencySymbol),
    decimalDigits: 2,
  );
  final when = DateFormat('MMM d, yyyy · h:mm a').format(order.createdAt);

  doc.addPage(
    pw.Page(
      pageFormat: const PdfPageFormat(226.77, double.infinity, marginAll: 14),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'CasinPOS',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    context.storeName,
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    context.businessTypeLabel,
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            _divider(),
            pw.SizedBox(height: 6),
            _row('Receipt', order.orderNo),
            _row('Date', when),
            _row('Payment', order.paymentMethod.label),
            if (context.cashierName != null && context.cashierName!.isNotEmpty)
              _row('Cashier', context.cashierName!),
            _row('Status', order.status),
            pw.SizedBox(height: 6),
            _divider(),
            pw.SizedBox(height: 6),
            pw.Text(
              'ITEMS',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            for (final item in order.items) ...[
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          item.name,
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          '${item.qty} × ${money.format(item.unitPrice)}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                  pw.Text(
                    money.format(item.qty * item.unitPrice),
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
            ],
            pw.SizedBox(height: 4),
            _divider(),
            pw.SizedBox(height: 6),
            _row('Subtotal', money.format(order.subtotal)),
            _row('Tax / VAT', money.format(order.tax)),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  money.format(order.total),
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            _divider(),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Thank you for your purchase!',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text(
                'Powered by CasinPOS',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
            ),
          ],
        );
      },
    ),
  );

  return doc;
}

/// Prefer the true peso sign; normalize common alternates.
String _pdfCurrencySymbol(String raw) {
  final s = raw.trim();
  if (s == 'P' || s == 'Php' || s == 'PHP' || s == 'php') return '₱';
  if (s.isEmpty) return '₱';
  return s;
}

pw.Widget _divider() => pw.Container(
      height: 1,
      color: PdfColors.grey400,
    );

pw.Widget _row(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Flexible(
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
