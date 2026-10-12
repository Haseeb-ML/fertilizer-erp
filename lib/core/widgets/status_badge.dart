import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? backgroundColor;
  final bool isSuccess;
  final bool isWarning;
  final bool isDanger;

  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.backgroundColor,
    this.isSuccess = false,
    this.isWarning = false,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    Color textColor = AppColors.textPrimary;
    Color bgColor = AppColors.divider;

    if (isSuccess ||
        label.toUpperCase() == 'PAID' ||
        label.toUpperCase() == 'ACTIVE') {
      textColor = AppColors.success;
      bgColor = AppColors.successBg;
    } else if (isWarning ||
        label.toUpperCase() == 'PARTIAL' ||
        label.toUpperCase() == 'LOW STOCK') {
      textColor = AppColors.warning;
      bgColor = AppColors.warningBg;
    } else if (isDanger ||
        label.toUpperCase() == 'UNPAID' ||
        label.toUpperCase() == 'INACTIVE' ||
        label.toUpperCase() == 'REVERSED') {
      textColor = AppColors.danger;
      bgColor = AppColors.dangerBg;
    } else if (color != null) {
      textColor = color!;
      bgColor = backgroundColor ?? color!.withOpacity(0.12);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
