import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sale.dart';
import '../models/business_settings.dart';
import '../models/ledger_entry.dart';
import '../models/report_models.dart';
import '../models/product.dart';
import '../utils/currency_formatter.dart';

class PdfService {
  /// Builds the pw.Document for a PDF Invoice
  static Future<pw.Document> buildSaleInvoiceDocument({
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

    return pdf;
  }

  /// Previews / prints the PDF invoice via system print spooler
  static Future<void> printSaleInvoice({
    required Sale sale,
    required BusinessSettings settings,
  }) async {
    final pdf = await buildSaleInvoiceDocument(sale: sale, settings: settings);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_${sale.invoiceNumber}.pdf',
    );
  }

  /// Safely shares PDF file or falls back to browser download/preview if native share unsupported
  static Future<void> _safeShareOrDownloadPdf({
    required Uint8List bytes,
    required String filename,
    String? shareText,
  }) async {
    bool shared = false;
    try {
      shared = await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
      );
    } catch (_) {
      shared = false;
    }

    if (!shared) {
      try {
        final xFile = XFile.fromData(
          bytes,
          name: filename,
          mimeType: 'application/pdf',
        );
        await Share.shareXFiles(
          [xFile],
          text: shareText ?? filename,
        );
        shared = true;
      } catch (_) {
        shared = false;
      }
    }

    // On Web or if sharing was not supported (e.g. desktop PC browser), open PDF preview/download spooler
    if (!shared || kIsWeb) {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: filename,
      );
    }
  }

  /// Cleans phone number to international WhatsApp format (e.g. 03001234567 -> 923001234567)
  static String cleanPhoneNumber(String? raw) {
    if (raw == null) return '';
    String clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0092')) {
      clean = clean.substring(2);
    } else if (clean.startsWith('03')) {
      clean = '92${clean.substring(1)}';
    } else if (clean.startsWith('3') && clean.length == 10) {
      clean = '92$clean';
    }
    return clean;
  }

  /// Checks if a phone number matches standard Pakistani mobile format (0300-0349, 0355)
  static bool isValidPakistaniMobile(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    final clean = cleanPhoneNumber(phone);
    if (clean.length != 12 || !clean.startsWith('923')) return false;
    final prefix = int.tryParse(clean.substring(2, 5));
    if (prefix == null) return false;
    return (prefix >= 300 && prefix <= 349) || prefix == 355;
  }

  /// Directly launches WhatsApp with pre-filled message (WhatsApp App on mobile/iOS Safari PWA, or WhatsApp Web on desktop)
  static Future<bool> launchWhatsApp({
    String? phone,
    required String message,
  }) async {
    final cleanPhone = cleanPhoneNumber(phone);
    final hasValidTarget =
        cleanPhone.isNotEmpty && isValidPakistaniMobile(cleanPhone);
    final encoded = Uri.encodeComponent(message);

    // 1. Direct App Scheme (Ensures flawless transition in iOS Safari PWA standalone mode & mobile app)
    // If the phone number is invalid (like 0358...), we omit the phone parameter so WhatsApp opens
    // the contact selector smoothly instead of showing "+92 ... is not a valid phone number" error!
    final nativeScheme = hasValidTarget
        ? 'whatsapp://send?phone=$cleanPhone&text=$encoded'
        : 'whatsapp://send?text=$encoded';
    final nativeUri = Uri.parse(nativeScheme);

    // 2. Universal Web Link (Fallback for desktop web / WhatsApp Web)
    final webUrl = hasValidTarget
        ? 'https://wa.me/$cleanPhone?text=$encoded'
        : 'https://api.whatsapp.com/send?text=$encoded';
    final webUri = Uri.parse(webUrl);

    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    try {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        return await launchUrl(webUri);
      } catch (_) {
        return false;
      }
    }
  }

  /// Opens WhatsApp with formatted Sales Invoice breakdown
  static Future<void> shareSaleInvoiceWhatsApp({
    required Sale sale,
    required BusinessSettings settings,
    String? customerPhone,
  }) async {
    final itemsSummary = sale.items
        .map((i) =>
            '• ${i.productName} (${i.quantity.toStringAsFixed(0)} ${i.unit}) = Rs. ${CurrencyFormatter.format(i.totalPrice, showSymbol: false)}')
        .join('\n');

    final message = '''
*${settings.businessName}*
${settings.ownerName.isNotEmpty ? "پروپرائیٹر: ${settings.ownerName}\n" : ""}${settings.phone.isNotEmpty ? "رابطہ: ${settings.phone}\n" : ""}━━━━━━━━━━━━━━━━━━━━
🧾 *سیلز انوائس #${sale.invoiceNumber}*
👤 *کسٹمر:* ${sale.customerName}
${customerPhone != null && customerPhone.isNotEmpty ? "📱 *فون:* $customerPhone\n" : ""}📅 *تاریخ:* ${sale.saleDate.substring(0, 10)}
💳 *ادائیگی کا طریقہ:* ${sale.paymentMethod}
━━━━━━━━━━━━━━━━━━━━
*آئٹمز کی تفصیل (Items):*
$itemsSummary
━━━━━━━━━━━━━━━━━━━━
💵 *کل رقم (Grand Total):* Rs. ${CurrencyFormatter.format(sale.grandTotal, showSymbol: false)}
✅ *وصول شدہ رقم (Paid):* Rs. ${CurrencyFormatter.format(sale.paidAmount, showSymbol: false)}
${sale.balanceDue > 0 ? "🔴 *بقایا جات (Balance Due):* Rs. ${CurrencyFormatter.format(sale.balanceDue, showSymbol: false)}" : "🟢 *کھاتہ کلیئر (Fully Paid)*"}

شکریہ برائے خریداری!
'''.trim();

    await launchWhatsApp(phone: customerPhone, message: message);
  }

  /// Directly opens WhatsApp and native share/download with the PDF invoice
  static Future<void> shareSaleInvoice({
    required Sale sale,
    required BusinessSettings settings,
    String? customerPhone,
  }) async {
    // 1. Launch WhatsApp with the customer's chat & invoice message
    await shareSaleInvoiceWhatsApp(
      sale: sale,
      settings: settings,
      customerPhone: customerPhone,
    );

    // 2. Also generate and share or download the PDF document
    final pdf = await buildSaleInvoiceDocument(sale: sale, settings: settings);
    final bytes = await pdf.save();
    await _safeShareOrDownloadPdf(
      bytes: bytes,
      filename: 'Invoice_${sale.invoiceNumber}.pdf',
      shareText: 'Sales Invoice ${sale.invoiceNumber} - ${sale.customerName}',
    );
  }

  /// Builds the pw.Document for Customer or Supplier Statement PDF
  static Future<pw.Document> buildLedgerStatementDocument({
    required String partyName,
    required String partyType,
    String? partyPhone,
    String? partyAddress,
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

    final formattedDate = DateTime.now().toString().substring(0, 10);
    final isCustomer = partyType.toLowerCase().contains('customer');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Business & Title Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 44,
                          height: 44,
                          margin: const pw.EdgeInsets.only(right: 10),
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
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green900,
                            ),
                          ),
                          if (settings.ownerName.isNotEmpty)
                            pw.Text(
                              'Proprietor: ${settings.ownerName}',
                              style: const pw.TextStyle(
                                fontSize: 8.5,
                                color: PdfColors.grey700,
                              ),
                            ),
                          if (settings.phone.isNotEmpty ||
                              settings.address.isNotEmpty)
                            pw.Text(
                              [
                                if (settings.phone.isNotEmpty)
                                  'Tel: ${settings.phone}',
                                if (settings.address.isNotEmpty)
                                  settings.address,
                              ].join(' | '),
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey700,
                              ),
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
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green800,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          '$partyType STATEMENT'.toUpperCase(),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Date: $formattedDate',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                      pw.Text(
                        'Page ${context.pageNumber} of ${context.pagesCount}',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // Party Details & Balance Card
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(5),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Text(
                                '$partyType: ',
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey700,
                                ),
                              ),
                              pw.Text(
                                partyName,
                                style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Phone: ${partyPhone != null && partyPhone.isNotEmpty ? partyPhone : 'Not Provided'} | Address: ${partyAddress != null && partyAddress.isNotEmpty ? partyAddress : 'Not Provided'}',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: pw.BoxDecoration(
                        color: currentBalance > 0
                            ? (isCustomer ? PdfColors.red50 : PdfColors.amber50)
                            : PdfColors.green50,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(
                          color: currentBalance > 0
                              ? (isCustomer
                                  ? PdfColors.red400
                                  : PdfColors.amber700)
                              : PdfColors.green400,
                          width: 0.8,
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            isCustomer
                                ? (currentBalance > 0
                                    ? 'Receivable (Balance Due)'
                                    : 'Account Cleared')
                                : (currentBalance > 0
                                    ? 'Payable (Balance Due)'
                                    : 'Account Cleared'),
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              color: currentBalance > 0
                                  ? (isCustomer
                                      ? PdfColors.red900
                                      : PdfColors.brown900)
                                  : PdfColors.green900,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text(
                            CurrencyFormatter.formatPdf(currentBalance),
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: currentBalance > 0
                                  ? (isCustomer
                                      ? PdfColors.red800
                                      : PdfColors.brown800)
                                  : PdfColors.green800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
        build: (context) => [
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: 0.5,
            ),
            columnWidths: {
              0: const pw.FixedColumnWidth(68), // Date e.g. 2026-10-14
              1: const pw.FlexColumnWidth(3.8), // Description & Items Detail
              2: const pw.FixedColumnWidth(66), // Debit (Rs.)
              3: const pw.FixedColumnWidth(66), // Credit (Rs.)
              4: const pw.FixedColumnWidth(72), // Balance (Rs.)
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                children: [
                  _th('Date', fontSize: 8.5),
                  _th('Description & Items Detail',
                      align: pw.TextAlign.left, fontSize: 8.5),
                  _th('Debit (Rs.)', align: pw.TextAlign.right, fontSize: 8.5),
                  _th('Credit (Rs.)', align: pw.TextAlign.right, fontSize: 8.5),
                  _th('Balance (Rs.)',
                      align: pw.TextAlign.right, fontSize: 8.5),
                ],
              ),
              ...entries.map(
                (e) {
                  final desc = _cleanPdfText(e.description);
                  final items = e.itemsDetails
                      .map((d) => '- ${_cleanPdfText(d)}')
                      .join('\n');
                  final fullDesc = items.isNotEmpty ? '$desc\n$items' : desc;

                  return pw.TableRow(
                    children: [
                      _td(e.transactionDate,
                          align: pw.TextAlign.center, fontSize: 8),
                      _td(fullDesc, fontSize: 8),
                      _td(
                        e.debit > 0
                            ? CurrencyFormatter.format(
                                e.debit,
                                showSymbol: false,
                              )
                            : '-',
                        align: pw.TextAlign.right,
                        fontSize: 8,
                      ),
                      _td(
                        e.credit > 0
                            ? CurrencyFormatter.format(
                                e.credit,
                                showSymbol: false,
                              )
                            : '-',
                        align: pw.TextAlign.right,
                        fontSize: 8,
                      ),
                      _td(
                        CurrencyFormatter.format(
                          e.runningBalance,
                          showSymbol: false,
                        ),
                        align: pw.TextAlign.right,
                        fontSize: 8,
                        isBold: true,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  /// Previews / prints Customer or Supplier Statement PDF
  static Future<void> printLedgerStatement({
    required String partyName,
    required String partyType,
    String? partyPhone,
    String? partyAddress,
    required List<LedgerEntry> entries,
    required double currentBalance,
    required BusinessSettings settings,
  }) async {
    final pdf = await buildLedgerStatementDocument(
      partyName: partyName,
      partyType: partyType,
      partyPhone: partyPhone,
      partyAddress: partyAddress,
      entries: entries,
      currentBalance: currentBalance,
      settings: settings,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${partyName}_Statement.pdf',
    );
  }

  /// Opens WhatsApp with formatted customer/supplier ledger statement
  static Future<void> shareLedgerWhatsApp({
    required String partyName,
    required String partyType,
    String? partyPhone,
    required double currentBalance,
    required List<LedgerEntry> entries,
    required BusinessSettings settings,
  }) async {
    final isCustomer = partyType.toLowerCase().contains('customer');
    final balanceFormatted =
        CurrencyFormatter.format(currentBalance, showSymbol: false);
    final statusText = currentBalance > 0
        ? (isCustomer
            ? 'واجب الاداء بقایا (Receivable)'
            : 'واجب الاداء رقم (Payable)')
        : 'کھاتہ کلیئر (Account Cleared)';

    final recent = entries.reversed.take(5).toList();
    final lines = <String>[];
    for (final e in recent) {
      final amt = e.debit > 0
          ? 'بنام / Debit: Rs. ${CurrencyFormatter.format(e.debit, showSymbol: false)}'
          : 'جمع / Credit: Rs. ${CurrencyFormatter.format(e.credit, showSymbol: false)}';
      lines.add('• ${e.transactionDate} | ${e.description} | $amt');
    }

    final message = '''
*${settings.businessName}*
${settings.ownerName.isNotEmpty ? "پروپرائیٹر: ${settings.ownerName}\n" : ""}${settings.phone.isNotEmpty ? "رابطہ: ${settings.phone}\n" : ""}━━━━━━━━━━━━━━━━━━━━
📄 *کھاتہ سٹیٹمنٹ (${isCustomer ? "کسٹمر" : "سپلائر"} / $partyType)*
👤 *نام:* $partyName
${partyPhone != null && partyPhone.isNotEmpty ? "📱 *فون:* $partyPhone\n" : ""}📅 *تاریخ:* ${DateTime.now().toString().substring(0, 10)}
💰 *موجودہ بقایا بیلنس:* Rs. $balanceFormatted ($statusText)
━━━━━━━━━━━━━━━━━━━━
*حالیہ ٹرانزیکشنز (Recent Transactions):*
${lines.isEmpty ? "کوئی ٹرانزیکشن موجود نہیں" : lines.join('\n')}

شکریہ برائے تعاون!
'''.trim();

    await launchWhatsApp(phone: partyPhone, message: message);
  }

  /// Directly opens WhatsApp and native share/download with the PDF statement
  static Future<void> shareLedgerStatement({
    required String partyName,
    required String partyType,
    String? partyPhone,
    String? partyAddress,
    required List<LedgerEntry> entries,
    required double currentBalance,
    required BusinessSettings settings,
  }) async {
    // 1. Launch WhatsApp with the customer's / supplier's chat & formatted statement
    await shareLedgerWhatsApp(
      partyName: partyName,
      partyType: partyType,
      partyPhone: partyPhone,
      currentBalance: currentBalance,
      entries: entries,
      settings: settings,
    );

    // 2. Also generate and share or download the PDF document
    final pdf = await buildLedgerStatementDocument(
      partyName: partyName,
      partyType: partyType,
      partyPhone: partyPhone,
      partyAddress: partyAddress,
      entries: entries,
      currentBalance: currentBalance,
      settings: settings,
    );
    final bytes = await pdf.save();
    await _safeShareOrDownloadPdf(
      bytes: bytes,
      filename: '${partyName}_Statement.pdf',
      shareText: '$partyType Statement - $partyName',
    );
  }

  /// Builds the pw.Document for Profit & Loss Statement PDF
  static Future<pw.Document> buildProfitLossDocument({
    required ProfitLossReport report,
    required BusinessSettings settings,
    String? fromDate,
    String? toDate,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final imageBytes = await rootBundle.load('assets/images/app_logo.png');
      logoImage = pw.MemoryImage(imageBytes.buffer.asUint8List());
    } catch (_) {
      // Graceful fallback
    }

    final isProfit = report.netProfit >= 0;
    final periodText = (fromDate != null &&
            fromDate.isNotEmpty &&
            toDate != null &&
            toDate.isNotEmpty)
        ? '$fromDate to $toDate'
        : (fromDate != null && fromDate.isNotEmpty
            ? 'From $fromDate'
            : 'All Time');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
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
                              color: PdfColors.green900,
                            ),
                          ),
                          if (settings.phone.isNotEmpty)
                            pw.Text(
                              'Phone: ${settings.phone}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          if (settings.address.isNotEmpty)
                            pw.Text(
                              settings.address,
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'PROFIT & LOSS STATEMENT',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Period: $periodText',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        'Generated: ${DateTime.now().toLocal().toString().substring(0, 16)}',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1.5, color: PdfColors.green900),
              pw.SizedBox(height: 12),
            ],
          );
        },
        build: (context) => [
          // KPI Metric Summary Row
          pw.Row(
            children: [
              _metricBox(
                'Net Revenue',
                CurrencyFormatter.formatPdf(report.netRevenue),
                PdfColors.blue800,
              ),
              pw.SizedBox(width: 8),
              _metricBox(
                'COGS (Cost)',
                CurrencyFormatter.formatPdf(report.costOfGoodsSold),
                PdfColors.grey800,
              ),
              pw.SizedBox(width: 8),
              _metricBox(
                'Gross Profit',
                '${CurrencyFormatter.formatPdf(report.grossProfit)}\n(${report.grossMarginPercent.toStringAsFixed(1)}%)',
                PdfColors.green800,
              ),
              pw.SizedBox(width: 8),
              _metricBox(
                isProfit ? 'Net Profit' : 'Net Loss',
                '${CurrencyFormatter.formatPdf(report.netProfit.abs())}\n(${report.netMarginPercent.toStringAsFixed(1)}%)',
                isProfit ? PdfColors.green900 : PdfColors.red900,
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // Trading & Operating Statement Table
          pw.Text(
            '1. Financial Statement Summary',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                _totalRow(
                  'Gross Sales Revenue',
                  CurrencyFormatter.formatPdf(report.totalRevenue),
                ),
                if (report.totalReturns > 0)
                  _totalRow(
                    'Less: Sales Returns',
                    '- ${CurrencyFormatter.formatPdf(report.totalReturns)}',
                    color: PdfColors.red800,
                  ),
                _totalRow(
                  'Net Sales Revenue',
                  CurrencyFormatter.formatPdf(report.netRevenue),
                  isBold: true,
                ),
                pw.Divider(color: PdfColors.grey300, height: 10),
                _totalRow(
                  'Less: Cost of Goods Sold (Dynamic FIFO COGS)',
                  '- ${CurrencyFormatter.formatPdf(report.costOfGoodsSold)}',
                ),
                pw.Divider(color: PdfColors.grey400, height: 12),
                _totalRow(
                  'GROSS PROFIT',
                  '${CurrencyFormatter.formatPdf(report.grossProfit)}  (${report.grossMarginPercent.toStringAsFixed(1)}% Margin)',
                  isBold: true,
                  fontSize: 11,
                  color: PdfColors.green900,
                ),
                pw.Divider(color: PdfColors.grey300, height: 10),
                _totalRow(
                  'Less: Operating Expenses',
                  '- ${CurrencyFormatter.formatPdf(report.totalExpenses)}',
                  color: PdfColors.red800,
                ),
                pw.Divider(color: PdfColors.grey900, thickness: 1.5, height: 14),
                _totalRow(
                  isProfit ? 'ESTIMATED NET PROFIT' : 'NET LOSS',
                  '${isProfit ? "" : "-"}${CurrencyFormatter.formatPdf(report.netProfit.abs())}  (${report.netMarginPercent.toStringAsFixed(1)}% Margin)',
                  isBold: true,
                  fontSize: 12,
                  color: isProfit ? PdfColors.green900 : PdfColors.red900,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),

          // Product-wise profitability breakdown (if any)
          if (report.productBreakdown.isNotEmpty) ...[
            pw.Text(
              '2. Product-wise Profit Breakdown',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _th('#'),
                    _th('Product Name'),
                    _th('Category'),
                    _th('Qty Sold'),
                    _th('Revenue'),
                    _th('Cost (COGS)'),
                    _th('Gross Profit'),
                    _th('Margin %'),
                  ],
                ),
                ...report.productBreakdown.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  return pw.TableRow(
                    children: [
                      _td(idx.toString(), align: pw.TextAlign.center),
                      _td(item.productName),
                      _td(item.category),
                      _td(
                        item.quantitySold == item.quantitySold.roundToDouble()
                            ? item.quantitySold.toInt().toString()
                            : item.quantitySold.toString(),
                        align: pw.TextAlign.center,
                      ),
                      _td(
                        CurrencyFormatter.formatPdf(item.totalRevenue),
                        align: pw.TextAlign.right,
                      ),
                      _td(
                        CurrencyFormatter.formatPdf(item.totalCost),
                        align: pw.TextAlign.right,
                      ),
                      _td(
                        CurrencyFormatter.formatPdf(item.grossProfit),
                        align: pw.TextAlign.right,
                      ),
                      _td(
                        '${item.marginPercent.toStringAsFixed(1)}%',
                        align: pw.TextAlign.center,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 18),
          ],

          // Operating Expenses breakdown (if any)
          if (report.expenseBreakdown.isNotEmpty) ...[
            pw.Text(
              '3. Operating Expenses Breakdown',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _th('#'),
                    _th('Expense Category'),
                    _th('Amount'),
                    _th('% of Expenses'),
                  ],
                ),
                ...report.expenseBreakdown.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final exp = entry.value;
                  return pw.TableRow(
                    children: [
                      _td(idx.toString(), align: pw.TextAlign.center),
                      _td(exp.category),
                      _td(
                        CurrencyFormatter.formatPdf(exp.amount),
                        align: pw.TextAlign.right,
                      ),
                      _td(
                        '${exp.percentage.toStringAsFixed(1)}%',
                        align: pw.TextAlign.center,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          // Signature section
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Prepared By: __________________',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'This is a computer-generated statement.',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Authorized Signature: __________________',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  /// Prints the Profit & Loss Statement via system print spooler
  static Future<void> printProfitLossStatement({
    required ProfitLossReport report,
    required BusinessSettings settings,
    String? fromDate,
    String? toDate,
  }) async {
    final pdf = await buildProfitLossDocument(
      report: report,
      settings: settings,
      fromDate: fromDate,
      toDate: toDate,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Profit_and_Loss_Statement.pdf',
    );
  }

  /// Shares the Profit & Loss Statement via WhatsApp / system share sheet
  static Future<void> shareProfitLossStatement({
    required ProfitLossReport report,
    required BusinessSettings settings,
    String? fromDate,
    String? toDate,
  }) async {
    final pdf = await buildProfitLossDocument(
      report: report,
      settings: settings,
      fromDate: fromDate,
      toDate: toDate,
    );
    final bytes = await pdf.save();
    await _safeShareOrDownloadPdf(
      bytes: bytes,
      filename: 'Profit_and_Loss_Statement.pdf',
      shareText: 'Profit & Loss Statement - ${settings.businessName}',
    );
  }

  static pw.Widget _metricBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 1),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Sanitizes text to remove non-Latin-1 characters (such as ₨, ×, •, — and Urdu script) that cause missing glyph box artifacts in standard PDF Helvetica
  static String _cleanPdfText(String text) {
    return text
        .replaceAll('₨', 'Rs. ')
        .replaceAll('×', 'x')
        .replaceAll('•', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll(RegExp(r'[\u0600-\u06FF]'), '')
        .replaceAll('()', '')
        .replaceAll('( )', '')
        .trim();
  }

  static pw.Widget _th(
    String text, {
    pw.TextAlign align = pw.TextAlign.center,
    double fontSize = 9,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: pw.Text(
        _cleanPdfText(text),
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSize),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _td(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    double fontSize = 9,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(
        _cleanPdfText(text),
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
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

  // ---------------------------------------------------------------------------
  // SALES & REVENUE REPORT PDF
  // ---------------------------------------------------------------------------

  /// Builds PDF for Sales & Revenue Report
  static Future<pw.Document> buildSalesReportDocument({
    required SalesSummaryReport summary,
    required List<ProductSalesReport> products,
    required BusinessSettings settings,
    String? fromDate,
    String? toDate,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final imageBytes = await rootBundle.load('assets/images/app_logo.png');
      logoImage = pw.MemoryImage(imageBytes.buffer.asUint8List());
    } catch (_) {}

    final dateRange = (fromDate != null &&
            fromDate.isNotEmpty &&
            toDate != null &&
            toDate.isNotEmpty)
        ? '$fromDate to $toDate'
        : (fromDate != null && fromDate.isNotEmpty
            ? 'From $fromDate'
            : 'All Time');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
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
                              color: PdfColors.green900,
                            ),
                          ),
                          if (settings.address.isNotEmpty)
                            pw.Text(
                              settings.address,
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          if (settings.phone.isNotEmpty)
                            pw.Text(
                              'Tel: ${settings.phone}',
                              style: const pw.TextStyle(fontSize: 9),
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
                          'SALES REPORT',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Period: $dateRange',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.SizedBox(height: 6),
            ],
          );
        },
        build: (context) => [
          // Summary Metrics Grid
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            ),
            child: pw.Column(
              children: [
                _totalRow(
                  'Gross Sales Revenue:',
                  CurrencyFormatter.formatPdf(summary.totalSales),
                ),
                _totalRow(
                  'Discounts Given:',
                  CurrencyFormatter.formatPdf(summary.totalDiscount),
                  color: PdfColors.red800,
                ),
                _totalRow(
                  'Net Sales Revenue:',
                  CurrencyFormatter.formatPdf(summary.netSales),
                  isBold: true,
                ),
                _totalRow(
                  'Cash Collected:',
                  CurrencyFormatter.formatPdf(summary.totalPaid),
                  color: PdfColors.green800,
                ),
                _totalRow(
                  'Receivables Due:',
                  CurrencyFormatter.formatPdf(summary.totalBalanceDue),
                  color: PdfColors.red800,
                ),
                _totalRow(
                  'Total Invoices Count:',
                  '${summary.invoiceCount} invoices',
                ),
                _totalRow(
                  'Gross Profit:',
                  CurrencyFormatter.formatPdf(summary.grossProfit),
                  isBold: true,
                  color: PdfColors.green900,
                  fontSize: 11,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Product-Wise Sales Breakdown',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green900,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _th('Product Name'),
                  _th('Category'),
                  _th('Qty Sold'),
                  _th('Revenue (PKR)'),
                  _th('Cost (PKR)'),
                  _th('Profit (PKR)'),
                ],
              ),
              ...products.map(
                (p) => pw.TableRow(
                  children: [
                    _td(p.productName),
                    _td(p.category),
                    _td(
                      p.totalQuantity.toStringAsFixed(1),
                      align: pw.TextAlign.right,
                    ),
                    _td(
                      CurrencyFormatter.format(
                        p.totalRevenue,
                        showSymbol: false,
                      ),
                      align: pw.TextAlign.right,
                    ),
                    _td(
                      CurrencyFormatter.format(
                        p.totalCost,
                        showSymbol: false,
                      ),
                      align: pw.TextAlign.right,
                    ),
                    _td(
                      CurrencyFormatter.format(
                        p.profit,
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
      ),
    );

    return pdf;
  }

  static Future<void> printSalesReport({
    required SalesSummaryReport summary,
    required List<ProductSalesReport> products,
    required BusinessSettings settings,
    String? fromDate,
    String? toDate,
  }) async {
    final pdf = await buildSalesReportDocument(
      summary: summary,
      products: products,
      settings: settings,
      fromDate: fromDate,
      toDate: toDate,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Sales_Report.pdf',
    );
  }

  static Future<void> shareSalesReport({
    required SalesSummaryReport summary,
    required List<ProductSalesReport> products,
    required BusinessSettings settings,
    String? fromDate,
    String? toDate,
  }) async {
    final pdf = await buildSalesReportDocument(
      summary: summary,
      products: products,
      settings: settings,
      fromDate: fromDate,
      toDate: toDate,
    );
    final bytes = await pdf.save();
    await _safeShareOrDownloadPdf(
      bytes: bytes,
      filename: 'Sales_Report.pdf',
      shareText: 'Sales & Revenue Report',
    );
  }

  // ---------------------------------------------------------------------------
  // INVENTORY VALUATION REPORT PDF
  // ---------------------------------------------------------------------------

  /// Builds PDF for Inventory Valuation Report
  static Future<pw.Document> buildInventoryReportDocument({
    required InventoryValuationReport valuation,
    required List<Product> products,
    required BusinessSettings settings,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final imageBytes = await rootBundle.load('assets/images/app_logo.png');
      logoImage = pw.MemoryImage(imageBytes.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
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
                              color: PdfColors.green900,
                            ),
                          ),
                          if (settings.address.isNotEmpty)
                            pw.Text(
                              settings.address,
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          if (settings.phone.isNotEmpty)
                            pw.Text(
                              'Tel: ${settings.phone}',
                              style: const pw.TextStyle(fontSize: 9),
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
                          'INVENTORY REPORT',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Date: ${DateTime.now().toString().substring(0, 10)}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.SizedBox(height: 6),
            ],
          );
        },
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            ),
            child: pw.Column(
              children: [
                _totalRow(
                  'Total Active Products:',
                  '${valuation.totalProducts} items',
                ),
                _totalRow(
                  'Total Stock Quantity:',
                  '${valuation.totalStockQuantity.toStringAsFixed(1)} units',
                ),
                _totalRow(
                  'Total Cost Valuation:',
                  CurrencyFormatter.formatPdf(valuation.totalCostValue),
                ),
                _totalRow(
                  'Total Retail Valuation:',
                  CurrencyFormatter.formatPdf(valuation.totalRetailValue),
                ),
                _totalRow(
                  'Potential Gross Profit:',
                  CurrencyFormatter.formatPdf(valuation.potentialProfit),
                  isBold: true,
                  color: PdfColors.green900,
                  fontSize: 11,
                ),
                if (valuation.lowStockCount > 0)
                  _totalRow(
                    'Low Stock Alert Items:',
                    '${valuation.lowStockCount} items need re-order',
                    color: PdfColors.red800,
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Product Stock & Valuation Breakdown',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green900,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _th('Product Name'),
                  _th('Category'),
                  _th('Stock'),
                  _th('Unit'),
                  _th('Cost (PKR)'),
                  _th('Sale (PKR)'),
                  _th('Valuation (PKR)'),
                  _th('Status'),
                ],
              ),
              ...products.map(
                (p) => pw.TableRow(
                  children: [
                    _td(p.name),
                    _td(p.category),
                    _td(
                      p.currentStock.toStringAsFixed(1),
                      align: pw.TextAlign.right,
                    ),
                    _td(p.unit, align: pw.TextAlign.center),
                    _td(
                      CurrencyFormatter.format(
                        p.purchasePrice,
                        showSymbol: false,
                      ),
                      align: pw.TextAlign.right,
                    ),
                    _td(
                      CurrencyFormatter.format(
                        p.sellingPrice,
                        showSymbol: false,
                      ),
                      align: pw.TextAlign.right,
                    ),
                    _td(
                      CurrencyFormatter.format(
                        p.inventoryValuation,
                        showSymbol: false,
                      ),
                      align: pw.TextAlign.right,
                    ),
                    _td(
                      p.isLowStock ? 'LOW STOCK' : 'OK',
                      align: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  static Future<void> printInventoryReport({
    required InventoryValuationReport valuation,
    required List<Product> products,
    required BusinessSettings settings,
  }) async {
    final pdf = await buildInventoryReportDocument(
      valuation: valuation,
      products: products,
      settings: settings,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Inventory_Report.pdf',
    );
  }

  static Future<void> shareInventoryReport({
    required InventoryValuationReport valuation,
    required List<Product> products,
    required BusinessSettings settings,
  }) async {
    final pdf = await buildInventoryReportDocument(
      valuation: valuation,
      products: products,
      settings: settings,
    );
    final bytes = await pdf.save();
    await _safeShareOrDownloadPdf(
      bytes: bytes,
      filename: 'Inventory_Report.pdf',
      shareText: 'Inventory Valuation Report',
    );
  }

  // ---------------------------------------------------------------------------
  // PARTY BALANCE REPORT (CUSTOMER RECEIVABLES & SUPPLIER PAYABLES) PDF
  // ---------------------------------------------------------------------------

  /// Builds PDF for Customer Receivables or Supplier Payables Report
  static Future<pw.Document> buildPartyBalanceReportDocument({
    required String reportTitle,
    required String partyType,
    required List<PartyBalanceReport> list,
    required BusinessSettings settings,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final imageBytes = await rootBundle.load('assets/images/app_logo.png');
      logoImage = pw.MemoryImage(imageBytes.buffer.asUint8List());
    } catch (_) {}

    final totalBalance = list.fold<double>(
      0.0,
      (acc, item) => acc + item.balance,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
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
                              color: PdfColors.green900,
                            ),
                          ),
                          if (settings.address.isNotEmpty)
                            pw.Text(
                              settings.address,
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          if (settings.phone.isNotEmpty)
                            pw.Text(
                              'Tel: ${settings.phone}',
                              style: const pw.TextStyle(fontSize: 9),
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
                          partyType.toUpperCase(),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Date: ${DateTime.now().toString().substring(0, 10)}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.SizedBox(height: 6),
            ],
          );
        },
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                _cleanPdfText(reportTitle),
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900,
                ),
              ),
              pw.Text(
                'Total: ${CurrencyFormatter.formatPdf(totalBalance)}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red800,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _th('$partyType Name'),
                  _th('Phone'),
                  _th('Address / Village'),
                  _th('Balance (PKR)'),
                ],
              ),
              ...list.map(
                (p) => pw.TableRow(
                  children: [
                    _td(p.name),
                    _td(p.phone.isNotEmpty ? p.phone : '-'),
                    _td(p.address.isNotEmpty ? p.address : '-'),
                    _td(
                      CurrencyFormatter.format(
                        p.balance,
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
      ),
    );

    return pdf;
  }

  static Future<void> printPartyBalanceReport({
    required String reportTitle,
    required String partyType,
    required List<PartyBalanceReport> list,
    required BusinessSettings settings,
  }) async {
    final pdf = await buildPartyBalanceReportDocument(
      reportTitle: reportTitle,
      partyType: partyType,
      list: list,
      settings: settings,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${partyType}_Balance_Report.pdf',
    );
  }

  static Future<void> sharePartyBalanceReport({
    required String reportTitle,
    required String partyType,
    required List<PartyBalanceReport> list,
    required BusinessSettings settings,
  }) async {
    final pdf = await buildPartyBalanceReportDocument(
      reportTitle: reportTitle,
      partyType: partyType,
      list: list,
      settings: settings,
    );
    final bytes = await pdf.save();
    await _safeShareOrDownloadPdf(
      bytes: bytes,
      filename: '${partyType}_Balance_Report.pdf',
      shareText: reportTitle,
    );
  }
}
