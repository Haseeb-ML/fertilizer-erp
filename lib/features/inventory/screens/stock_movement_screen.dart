import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/product.dart';
import '../../../core/models/stock_movement.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/status_badge.dart';

class StockMovementScreen extends ConsumerWidget {
  final Product product;

  const StockMovementScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(productRepoProvider);

    return Scaffold(
      appBar: AppBar(title: Text('${product.name} History')),
      body: FutureBuilder<List<StockMovement>>(
        future: repo.getStockMovements(product.id!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final movements = snapshot.data ?? [];
          if (movements.isEmpty) {
            return const EmptyStateView(
              icon: Icons.history,
              title: 'No Movements Yet',
              description:
                  'Stock transactions will appear here as purchases and sales occur.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: movements.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final m = movements[index];
              final isPositive = m.quantity > 0;

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: isPositive
                        ? AppColors.successBg
                        : AppColors.dangerBg,
                    child: Icon(
                      isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isPositive ? AppColors.success : AppColors.danger,
                      size: 20,
                    ),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        m.movementType.replaceAll('_', ' '),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${isPositive ? '+' : ''}${m.quantity.toStringAsFixed(0)} ${product.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isPositive
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Date: ${m.movementDate} • Balance After: ${m.balanceAfter.toStringAsFixed(0)} ${product.unit}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (m.notes.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          m.notes,
                          style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
