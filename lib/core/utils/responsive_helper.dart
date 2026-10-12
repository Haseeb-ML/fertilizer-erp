import 'package:flutter/material.dart';

class ResponsiveHelper {
  static const double kSmallMobileWidth = 350.0;
  static const double kStandardMobileWidth = 430.0;
  static const double kTabletBreakpoint = 600.0;
  static const double kDesktopBreakpoint = 900.0;

  static bool isSmallPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < kSmallMobileWidth;
  }

  static bool isStandardPhone(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= kSmallMobileWidth && width < kTabletBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= kTabletBreakpoint && width < kDesktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= kDesktopBreakpoint;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Calculates responsive columns for dashboard and grid screens
  static int getDashboardColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 340) {
      return 1;
    } else if (width < 600) {
      return 2;
    } else if (width < 900) {
      return 3;
    } else {
      return 4;
    }
  }

  /// Calculates grid columns for products / cards
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 450) {
      return 1;
    } else if (width < 750) {
      return 2;
    } else if (width < 1100) {
      return 3;
    } else {
      return 4;
    }
  }

  static double getHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 340) return 10.0;
    if (width < 600) return 14.0;
    if (width < 900) return 20.0;
    return 32.0;
  }
}
