import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_translations.dart';
import '../../core/providers/app_providers.dart';
import '../dashboard/controllers/dashboard_controller.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../inventory/screens/product_list_screen.dart';
import '../sales/screens/sales_list_screen.dart';
import 'more_menu_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    DashboardScreen(),
    SalesListScreen(),
    ProductListScreen(),
    MoreMenuScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            ref.read(salesUpdateTriggerProvider.notifier).state++;
          } else if (index == 2) {
            ref.read(productsUpdateTriggerProvider.notifier).state++;
          } else if (index == 0) {
            ref.invalidate(dashboardDataProvider);
          }
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard),
            label: ref.tr('nav_dashboard'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.point_of_sale_outlined),
            activeIcon: const Icon(Icons.point_of_sale),
            label: ref.tr('nav_sales'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.inventory_2_outlined),
            activeIcon: const Icon(Icons.inventory_2),
            label: ref.tr('nav_inventory'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.grid_view),
            activeIcon: const Icon(Icons.grid_view_rounded),
            label: ref.tr('nav_more'),
          ),
        ],
      ),
    );
  }
}
