import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_tables.dart';
import '../../../core/localization/app_translations.dart';

class StorageGraphCard extends ConsumerWidget {
  final Map<String, int>? stats;
  final VoidCallback? onManageTap;
  final bool isDetailed;

  const StorageGraphCard({
    super.key,
    this.stats,
    this.onManageTap,
    this.isDetailed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesCount = stats?[DatabaseTables.sales] ?? 12;
    final ledgerCount = (stats?[DatabaseTables.customerLedger] ?? 18) +
        (stats?[DatabaseTables.customers] ?? 8);
    final productsCount = stats?[DatabaseTables.products] ?? 15;
    final backupCount = (stats?[DatabaseTables.stockMovements] ?? 24) +
        (stats?[DatabaseTables.payments] ?? 14);

    // Calculate simulated realistic storage footprint in MB against 4.0 TB
    final salesMb = (salesCount * 1.8 + 420.0).clamp(50.0, 1500.0);
    final ledgerMb = (ledgerCount * 1.4 + 280.0).clamp(40.0, 1000.0);
    final productsMb = (productsCount * 2.2 + 190.0).clamp(30.0, 800.0);
    final backupsMb = (backupCount * 1.1 + 330.0).clamp(60.0, 1200.0);

    final totalUsedMb = salesMb + ledgerMb + productsMb + backupsMb;
    final totalUsedGb = totalUsedMb / 1024.0;
    const totalCapacityTb = 4.0;
    const totalCapacityGb = totalCapacityTb * 1024.0; // 4096 GB
    final freeCapacityGb = totalCapacityGb - totalUsedGb;
    final freeCapacityTb = freeCapacityGb / 1024.0;
    final usedPercentage = (totalUsedGb / totalCapacityGb) * 100.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF00796B).withOpacity(0.2), width: 1.2),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFF0FDF4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF004D40), Color(0xFF00897B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF004D40).withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.storage_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref.tr('storage_4t_title'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF004D40),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ref.tr('storage_4t_sub'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (onManageTap != null)
                  TextButton.icon(
                    onPressed: onManageTap,
                    icon: const Icon(Icons.arrow_forward_ios, size: 12),
                    label: const Text(
                      'Manage',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF00796B),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Circular Visual Graph & Summary Info
            Row(
              children: [
                // Custom Circular Doughnut Chart
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CustomPaint(
                    painter: _StorageDoughnutPainter(
                      salesRatio: salesMb / totalUsedMb,
                      ledgerRatio: ledgerMb / totalUsedMb,
                      productsRatio: productsMb / totalUsedMb,
                      backupsRatio: backupsMb / totalUsedMb,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '4.0 TB',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF004D40),
                            ),
                          ),
                          Text(
                            '${totalUsedGb.toStringAsFixed(2)} GB',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Metrics & Breakdown Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Capacity: 4 TB',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF81C784)),
                            ),
                            child: const Text(
                              '99.9% Free',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Used: ${totalUsedGb.toStringAsFixed(2)} GB • Free: ${freeCapacityTb.toStringAsFixed(2)} TB',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Segmented Multi-color Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 8,
                          child: Row(
                            children: [
                              Flexible(
                                flex: (salesMb).round(),
                                child: Container(color: const Color(0xFF2E7D32)),
                              ),
                              Flexible(
                                flex: (ledgerMb).round(),
                                child: Container(color: const Color(0xFF0288D1)),
                              ),
                              Flexible(
                                flex: (productsMb).round(),
                                child: Container(color: const Color(0xFFFFA000)),
                              ),
                              Flexible(
                                flex: (backupsMb).round(),
                                child: Container(color: const Color(0xFF7B1FA2)),
                              ),
                              Flexible(
                                flex: 400, // Visual representation of remaining 4TB space
                                child: Container(color: const Color(0xFFE0E0E0)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Color-Coded Legend Grid
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildLegendItem(
                  color: const Color(0xFF2E7D32),
                  label: 'Sales Invoices',
                  size: '${salesMb.toStringAsFixed(0)} MB',
                ),
                _buildLegendItem(
                  color: const Color(0xFF0288D1),
                  label: 'Customer Ledgers',
                  size: '${ledgerMb.toStringAsFixed(0)} MB',
                ),
                _buildLegendItem(
                  color: const Color(0xFFFFA000),
                  label: 'Products & Stock',
                  size: '${productsMb.toStringAsFixed(0)} MB',
                ),
                _buildLegendItem(
                  color: const Color(0xFF7B1FA2),
                  label: 'Backups & Logs',
                  size: '${backupsMb.toStringAsFixed(0)} MB',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String size,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        Text(
          size,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StorageDoughnutPainter extends CustomPainter {
  final double salesRatio;
  final double ledgerRatio;
  final double productsRatio;
  final double backupsRatio;

  _StorageDoughnutPainter({
    required this.salesRatio,
    required this.ledgerRatio,
    required this.productsRatio,
    required this.backupsRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 8.0;
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    // Background circle (representing available 4TB space)
    final bgPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    final rect = Rect.fromCircle(center: center, radius: radius);
    double startAngle = -math.pi / 2;

    // Draw segment function
    void drawArcSegment(double ratio, Color color) {
      final sweepAngle = ratio * 2 * math.pi;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    drawArcSegment(salesRatio, const Color(0xFF2E7D32));
    drawArcSegment(ledgerRatio, const Color(0xFF0288D1));
    drawArcSegment(productsRatio, const Color(0xFFFFA000));
    drawArcSegment(backupsRatio, const Color(0xFF7B1FA2));
  }

  @override
  bool shouldRepaint(covariant _StorageDoughnutPainter oldDelegate) => true;
}
