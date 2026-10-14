import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/report_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/csv_service.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';

enum DateFilterPreset { allTime, thisMonth, thisYear, today, custom }

class ProfitLossReportScreen extends ConsumerStatefulWidget {
  const ProfitLossReportScreen({super.key});

  @override
  ConsumerState<ProfitLossReportScreen> createState() =>
      _ProfitLossReportScreenState();
}

class _ProfitLossReportScreenState
    extends ConsumerState<ProfitLossReportScreen> {
  DateFilterPreset _preset = DateFilterPreset.thisMonth;
  DateTime? _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _toDate = DateTime.now();
  bool _isProcessingPdf = false;

  void _selectPreset(DateFilterPreset preset) {
    final now = DateTime.now();
    setState(() {
      _preset = preset;
      switch (preset) {
        case DateFilterPreset.allTime:
          _fromDate = null;
          _toDate = null;
          break;
        case DateFilterPreset.thisMonth:
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate = now;
          break;
        case DateFilterPreset.thisYear:
          _fromDate = DateTime(now.year, 1, 1);
          _toDate = now;
          break;
        case DateFilterPreset.today:
          _fromDate = DateTime(now.year, now.month, now.day);
          _toDate = DateTime(now.year, now.month, now.day);
          break;
        case DateFilterPreset.custom:
          _fromDate ??= DateTime(now.year, now.month, 1);
          _toDate ??= now;
          break;
      }
    });
  }

  Future<void> _sharePdf(ProfitLossReport report) async {
    setState(() => _isProcessingPdf = true);
    try {
      final settings = await ref.read(businessSettingsProvider.future);
      final fromStr =
          _fromDate != null ? DateFormatter.toSqlDate(_fromDate!) : null;
      final toStr = _toDate != null ? DateFormatter.toSqlDate(_toDate!) : null;
      await PdfService.shareProfitLossStatement(
        report: report,
        settings: settings,
        fromDate: fromStr,
        toDate: toStr,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing PDF: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPdf = false);
    }
  }

  Future<void> _printPdf(ProfitLossReport report) async {
    setState(() => _isProcessingPdf = true);
    try {
      final settings = await ref.read(businessSettingsProvider.future);
      final fromStr =
          _fromDate != null ? DateFormatter.toSqlDate(_fromDate!) : null;
      final toStr = _toDate != null ? DateFormatter.toSqlDate(_toDate!) : null;
      await PdfService.printProfitLossStatement(
        report: report,
        settings: settings,
        fromDate: fromStr,
        toDate: toStr,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing PDF: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPdf = false);
    }
  }

  Future<void> _exportCsv(ProfitLossReport report) async {
    final periodDesc = _preset == DateFilterPreset.allTime
        ? 'All Time (تمام ریکارڈ)'
        : 'From: ${_fromDate != null ? DateFormatter.formatDate(_fromDate!) : "Start"} To: ${_toDate != null ? DateFormatter.formatDate(_toDate!) : "End"}';

    final rows = <List<dynamic>>[
      ['PROFIT & LOSS STATEMENT (نفع و نقصان گوشوارہ)'],
      ['Period', periodDesc],
      [],
      ['1. FINANCIAL SUMMARY (مالیاتی خلاصہ)'],
      ['Gross Sales Revenue (PKR)', report.totalRevenue],
      ['Less: Sales Returns (PKR)', report.totalReturns],
      ['Net Sales Revenue (PKR)', report.netRevenue],
      [
        'Less: Cost of Goods Sold (Dynamic FIFO COGS) (PKR)',
        report.costOfGoodsSold
      ],
      ['Gross Profit (PKR)', report.grossProfit],
      ['Gross Margin (%)', '${report.grossMarginPercent.toStringAsFixed(1)}%'],
      ['Less: Operational Expenses (PKR)', report.totalExpenses],
      ['Estimated Net Profit (PKR)', report.netProfit],
      ['Net Margin (%)', '${report.netMarginPercent.toStringAsFixed(1)}%'],
      ['Total Invoices Count', report.totalInvoices],
      [],
      ['2. PRODUCT-WISE PROFIT BREAKDOWN (مصنوعات کا منافع)'],
      [
        '#',
        'Product Name',
        'Category',
        'Quantity Sold',
        'Revenue (PKR)',
        'Cost (PKR)',
        'Gross Profit (PKR)',
        'Margin (%)'
      ],
      ...report.productBreakdown.asMap().entries.map((e) => [
            e.key + 1,
            e.value.productName,
            e.value.category,
            e.value.quantitySold,
            e.value.totalRevenue,
            e.value.totalCost,
            e.value.grossProfit,
            '${e.value.marginPercent.toStringAsFixed(1)}%',
          ]),
      [],
      ['3. OPERATING EXPENSES BREAKDOWN (اخراجات کی تفصیل)'],
      ['#', 'Category', 'Amount (PKR)', 'Percentage (%)'],
      ...report.expenseBreakdown.asMap().entries.map((e) => [
            e.key + 1,
            e.value.category,
            e.value.amount,
            '${e.value.percentage.toStringAsFixed(1)}%',
          ]),
    ];

    await CsvService.exportAndShareCsv(
      fileName: 'Profit_and_Loss_Statement.csv',
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(reportRepoProvider);
    final fromStr =
        _fromDate != null ? DateFormatter.toSqlDate(_fromDate!) : null;
    final toStr = _toDate != null ? DateFormatter.toSqlDate(_toDate!) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profit & Loss Statement'),
            Text(
              'نفع و نقصان گوشوارہ',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: FutureBuilder<ProfitLossReport>(
        future: repo.getProfitLossReport(fromDate: fromStr, toDate: toStr),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final report = snapshot.data!;
          final isNetProfitPositive = report.netProfit >= 0;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Quick Filter Chips Bar
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterChip(
                              label: 'All Time (سب ریکارڈ)',
                              preset: DateFilterPreset.allTime,
                            ),
                            const SizedBox(width: 6),
                            _filterChip(
                              label: 'This Month (یہ مہینہ)',
                              preset: DateFilterPreset.thisMonth,
                            ),
                            const SizedBox(width: 6),
                            _filterChip(
                              label: 'This Year (یہ سال)',
                              preset: DateFilterPreset.thisYear,
                            ),
                            const SizedBox(width: 6),
                            _filterChip(
                              label: 'Today (آج)',
                              preset: DateFilterPreset.today,
                            ),
                            const SizedBox(width: 6),
                            _filterChip(
                              label: 'Custom (اپنی مرضی)',
                              preset: DateFilterPreset.custom,
                            ),
                          ],
                        ),
                      ),
                      if (_preset == DateFilterPreset.custom) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _fromDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setState(() => _fromDate = picked);
                                  }
                                },
                                icon: const Icon(Icons.date_range, size: 14),
                                label: Text(
                                  _fromDate != null
                                      ? 'From: ${DateFormatter.formatDate(_fromDate!)}'
                                      : 'From: Any',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _toDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setState(() => _toDate = picked);
                                  }
                                },
                                icon: const Icon(Icons.event, size: 14),
                                label: Text(
                                  _toDate != null
                                      ? 'To: ${DateFormatter.formatDate(_toDate!)}'
                                      : 'To: Any',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Action Bar (Share WhatsApp PDF, Print, CSV)
                Container(
                  color: const Color(0xFFF1F8E9),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessingPdf
                              ? null
                              : () => _sharePdf(report),
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text(
                            'Share PDF (واٹس ایپ)',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _isProcessingPdf
                            ? null
                            : () => _printPdf(report),
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Print',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.download,
                            color: AppColors.primary, size: 20),
                        tooltip: 'Export CSV',
                        onPressed: () => _exportCsv(report),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Big Net Profit / Net Loss Hero Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isNetProfitPositive
                                ? AppColors.success.withOpacity(0.3)
                                : AppColors.danger.withOpacity(0.3),
                          ),
                        ),
                        color: isNetProfitPositive
                            ? AppColors.successBg
                            : AppColors.dangerBg,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isNetProfitPositive
                                            ? Icons.trending_up
                                            : Icons.trending_down,
                                        color: isNetProfitPositive
                                            ? AppColors.success
                                            : AppColors.danger,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isNetProfitPositive
                                            ? 'Net Profit (خالص منافع)'
                                            : 'Net Loss (خالص نقصان)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isNetProfitPositive
                                              ? AppColors.success
                                              : AppColors.danger,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (isNetProfitPositive
                                              ? AppColors.success
                                              : AppColors.danger)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Margin: ${report.netMarginPercent.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isNetProfitPositive
                                            ? AppColors.success
                                            : AppColors.danger,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  CurrencyFormatter.format(
                                      report.netProfit.abs()),
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: isNetProfitPositive
                                        ? AppColors.success
                                        : AppColors.danger,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${report.totalInvoices} Invoices recorded in this period',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. Executive Mini KPI Cards Row
                      Row(
                        children: [
                          Expanded(
                            child: _miniKpi(
                              title: 'Net Revenue',
                              subtitle: 'خالص فروخت',
                              value: CurrencyFormatter.format(report.netRevenue),
                              color: AppColors.info,
                              icon: Icons.point_of_sale,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _miniKpi(
                              title: 'COGS (Cost)',
                              subtitle: 'خرید لاگت',
                              value: CurrencyFormatter.format(
                                  report.costOfGoodsSold),
                              color: const Color(0xFF5D4037),
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _miniKpi(
                              title: 'Gross Profit',
                              subtitle:
                                  '${report.grossMarginPercent.toStringAsFixed(1)}% مارجن',
                              value: CurrencyFormatter.format(report.grossProfit),
                              color: AppColors.primary,
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 3. Itemized Financial Trading Account Card
                      Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Financial Trading Account',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    'کاروباری حساب کتاب',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              _accountingRow(
                                'Gross Sales Revenue (مجموعی فروخت)',
                                CurrencyFormatter.format(report.totalRevenue),
                              ),
                              if (report.totalReturns > 0)
                                _accountingRow(
                                  'Less: Sales Returns (مرجوعہ فروخت)',
                                  '- ${CurrencyFormatter.format(report.totalReturns)}',
                                  color: AppColors.danger,
                                ),
                              _accountingRow(
                                'Net Sales Revenue (خالص فروخت)',
                                CurrencyFormatter.format(report.netRevenue),
                                isBold: true,
                              ),
                              const Divider(height: 16),
                              _accountingRow(
                                'Less: Cost of Goods Sold (Dynamic COGS)',
                                '- ${CurrencyFormatter.format(report.costOfGoodsSold)}',
                                subtitle: 'مال کی اصل خرید لاگت',
                              ),
                              const Divider(height: 16),
                              _accountingRow(
                                'Gross Profit (مجموعی منافع)',
                                '${CurrencyFormatter.format(report.grossProfit)}  (${report.grossMarginPercent.toStringAsFixed(1)}%)',
                                isBold: true,
                                fontSize: 14,
                                color: AppColors.primary,
                                bgColor: AppColors.primary.withOpacity(0.06),
                              ),
                              const SizedBox(height: 12),
                              _accountingRow(
                                'Less: Operating Expenses (اخراجات)',
                                '- ${CurrencyFormatter.format(report.totalExpenses)}',
                                color: AppColors.danger,
                                subtitle: 'دکان و ملازمین کے اخراجات',
                              ),
                              const Divider(height: 20, thickness: 1.5),
                              _accountingRow(
                                isNetProfitPositive
                                    ? 'Net Profit (حتمی خالص منافع)'
                                    : 'Net Loss (حتمی نقصان)',
                                '${isNetProfitPositive ? "" : "-"}${CurrencyFormatter.format(report.netProfit.abs())}  (${report.netMarginPercent.toStringAsFixed(1)}%)',
                                isBold: true,
                                fontSize: 16,
                                color: isNetProfitPositive
                                    ? AppColors.success
                                    : AppColors.danger,
                                bgColor: (isNetProfitPositive
                                        ? AppColors.success
                                        : AppColors.danger)
                                    .withOpacity(0.08),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4. Product-wise Profit Breakdown Card
                      Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.analytics_outlined,
                                          size: 18, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Product-wise Profit Breakdown',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'مصنوعات کا منافع',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (report.productBreakdown.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Text(
                                      'No sales recorded in this period.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary),
                                    ),
                                  ),
                                )
                              else
                                ...report.productBreakdown.map((item) {
                                  final isItemProfitable =
                                      item.grossProfit >= 0;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FBE7),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.productName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: (isItemProfitable
                                                        ? AppColors.success
                                                        : AppColors.danger)
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Profit: ${CurrencyFormatter.format(item.grossProfit)} (${item.marginPercent.toStringAsFixed(1)}%)',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isItemProfitable
                                                      ? AppColors.success
                                                      : AppColors.danger,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Sold: ${item.quantitySold == item.quantitySold.roundToDouble() ? item.quantitySold.toInt() : item.quantitySold} Bags',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppColors.textSecondary,
                                              ),
                                            ),
                                            Text(
                                              'Revenue: ${CurrencyFormatter.format(item.totalRevenue)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              'Cost: ${CurrencyFormatter.format(item.totalCost)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 5. Operating Expenses Category Breakdown Card
                      Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.receipt_long,
                                          size: 18, color: AppColors.danger),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Operating Expenses Breakdown',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'اخراجات کی تفصیل',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (report.expenseBreakdown.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Text(
                                      'No expenses recorded in this period.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary),
                                    ),
                                  ),
                                )
                              else
                                ...report.expenseBreakdown.map((exp) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              exp.category,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '${CurrencyFormatter.format(exp.amount)} (${exp.percentage.toStringAsFixed(1)}%)',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.danger,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        LinearProgressIndicator(
                                          value: (exp.percentage / 100)
                                              .clamp(0.0, 1.0),
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                  Color>(
                                            Color(0xFFE57373),
                                          ),
                                          minHeight: 4,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required DateFilterPreset preset,
  }) {
    final isSelected = _preset == preset;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.grey.shade100,
      onSelected: (_) => _selectPreset(preset),
    );
  }

  Widget _miniKpi({
    required String title,
    required String subtitle,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 10, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
                fontSize: 9, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _accountingRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 12,
    Color? color,
    String? subtitle,
    Color? bgColor,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );

    if (bgColor != null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: content,
      );
    }
    return content;
  }
}
