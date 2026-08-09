import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/pos_models.dart';
import 'receipt_pdf.dart';

Future<void> openReceiptPdfPreview(
  BuildContext context, {
  required PosOrder order,
  required ReceiptPdfContext pdfContext,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReceiptPdfPreviewPage(order: order, pdfContext: pdfContext),
    ),
  );
}

class ReceiptPdfPreviewPage extends StatelessWidget {
  const ReceiptPdfPreviewPage({
    super.key,
    required this.order,
    required this.pdfContext,
  });

  final PosOrder order;
  final ReceiptPdfContext pdfContext;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate900,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        foregroundColor: Colors.white,
        title: Text(
          'Receipt ${order.orderNo}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        actions: [
          IconButton(
            tooltip: 'Share / save PDF',
            onPressed: () async {
              final doc = await buildReceiptPdf(order: order, context: pdfContext);
              await Printing.sharePdf(
                bytes: await doc.save(),
                filename: 'casinpos-receipt-${order.orderNo.replaceAll('#', '')}.pdf',
              );
            },
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) async {
          final doc = await buildReceiptPdf(order: order, context: pdfContext);
          return doc.save();
        },
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: 'casinpos-receipt-${order.orderNo.replaceAll('#', '')}.pdf',
        initialPageFormat: const PdfPageFormat(226.77, 600),
      ),
    );
  }
}
