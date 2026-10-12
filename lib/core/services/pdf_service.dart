import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/sale.dart';
import '../models/business_settings.dart';
import '../models/ledger_entry.dart';
import '../utils/currency_formatter.dart';

class PdfService {
  /// Generates and previews/prints or shares a PDF Invoice
  static Future<void> printSaleInvoice({
    required Sale sale,
    required BusinessSettings settings,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final imageBytes = await rootBundle.load('assets/images/app_logo.png');
      logoImage = pw.MemoryImage(imageBytes.buffer.asUint8List());
    } catch (_) {
      // Graceful fallback if asset cannot be read in test
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 48,
                          height: 48,
                          margin: const pw.EdgeInsets.only(right: 12),
                          child: pw.ClipRRect(
                            horizontalRadius: 6,
                            verticalRadius: 6,
                            child: pw.Image(logoImage),
                          ),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            settings.businessName,
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green900,
                            ),
                          ),
                          if (settings.ownerName.isNotEmpty)
                            pw.Text(
                              'Prop: ${settings.ownerName}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          if (settings.address.isNotEmpty)
                            pw.Text(
                              settings.address,
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          if (settings.phone.isNotEmpty)
                            pw.Text(
                              'Tel: ${settings.phone}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          if (settings.ntnStrn.isNotEmpty)
                            pw.Text(
                              'NTN/STRN: ${settings.ntnStrn}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green800,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'SALES INVOICE',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Invoice #: ${sale.invoiceNumber}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      pw.Text(
                        'Date: ${sale.saleDate}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        'Status: ${sale.paymentStatus}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.grey400),
              pw.SizedBox(height: 8),

              // Customer Info
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  children: [
                    pw.Text(
                      'Customer: ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    pw.Text(
                      sale.customerName,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Spacer(),
                    pw.Text(
                      'Payment Mode: ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.Text(
                      sale.paymentMethod,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(2),
                  5: const pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _th('#'),
                      _th('Product Description'),
                      _th('Unit'),
                      _th('Qty'),
                      _th('Rate (PKR)'),
                      _th('Total (PKR)'),
                    ],
                  ),
                  ...sale.items.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final item = entry.value;
                    return pw.TableRow(
                      children: [
                        _td('$idx', align: pw.TextAlign.center),
                        _td(item.productName),
                        _td(item.unit, align: pw.TextAlign.center),
                        _td(
                          item.quantity.toStringAsFixed(0),
                          align: pw.TextAlign.right,
                        ),
                        _td(
                          CurrencyFormatter.format(
                            item.unitPrice,
                            showSymbol: false,
                          ),
                          align: pw.TextAlign.right,
                        ),
                        _td(
                          CurrencyFormatter.format(
                            item.totalPrice,
                            showSymbol: false,
                          ),
                          align: pw.TextAlign.right,
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 12),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 220,
                    child: pw.Column(
                      children: [
                        _totalRow(
                          'Subtotal:',
                          CurrencyFormatter.formatPdf(sale.subtotal),
                        ),
                        if (sale.discount > 0)
                          _totalRow(
                            'Discount:',
                            '- ${CurrencyFormatter.formatPdf(sale.discount)}',
                          ),
                        pw.Divider(thickness: 1, color: PdfColors.grey400),
                        _totalRow(
                          'Grand Total:',
                          CurrencyFormatter.formatPdf(sale.grandTotal),
                          isBold: true,
                          fontSize: 12,
                        ),
                        _totalRow(
                          'Paid Amount:',
                          CurrencyFormatter.formatPdf(sale.paidAmount),
                        ),
                        _totalRow(
                          'Balance Due:',
                          CurrencyFormatter.formatPdf(sale.balanceDue),
                          isBold: true,
                          color: sale.balanceDue > 0
                              ? PdfColors.red800
                              : PdfColors.green800,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // Footer
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated offline by Fertilizer ERP',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Authorized Signature: _________________',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_${sale.invoiceNumber}.pdf',
    );
  }

  /// Generates and previews Customer or Supplier Statement PDF
  static Future<void> printLedgerStatement({
    required String partyName,
    required String partyType,
    required List<LedgerEntry> entries,
    required double currentBalance,
    required BusinessSettings settings,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final imageBytes = await rootBundle.load('assets/images/app_logo.png');
      logoImage = pw.MemoryImage(imageBytes.buffer.asUint8List());
    } catch (_) {
      // Fallback
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 44,
                      height: 44,
                      margin: const pw.EdgeInsets.only(right: 12),
                      child: pw.ClipRRect(
                        horizontalRadius: 6,
                        verticalRadius: 6,
                        child: pw.Image(logoImage),
                      ),
                    ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        settings.businessName,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'ACCOUNT STATEMENT: $partyName ($partyType)',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Current Outstanding Balance: ${CurrencyFormatter.formatPdf(currentBalance)}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _th('Date'),
                      _th('Description'),
                      _th('Debit (PKR)'),
                      _th('Credit (PKR)'),
                      _th('Balance (PKR)'),
                    ],
                  ),
                  ...entries.map(
                    (e) => pw.TableRow(
                      children: [
                        _td(e.transactionDate),
                        _td(e.description),
                        _td(
                          e.debit > 0
                              ? CurrencyFormatter.format(
                                  e.debit,
                                  showSymbol: false,
                                )
                              : '-',
                          align: pw.TextAlign.right,
                        ),
                        _td(
                          e.credit > 0
                              ? CurrencyFormatter.format(
                                  e.credit,
                                  showSymbol: false,
                                )
                              : '-',
                          align: pw.TextAlign.right,
                        ),
                        _td(
                          CurrencyFormatter.format(
                            e.runningBalance,
                            showSymbol: false,
                          ),
                          align: pw.TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${partyName}_Statement.pdf',
    );
  }

  static pw.Widget _th(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _td(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 10,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
