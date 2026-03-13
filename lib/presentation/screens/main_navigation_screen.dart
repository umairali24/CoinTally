import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/presentation/screens/dashboard_screen.dart';
import 'package:cointally/presentation/screens/budget_list_screen.dart';
import 'package:cointally/presentation/screens/account_list_screen.dart';
import 'package:cointally/presentation/screens/settings_screen.dart';
import 'package:cointally/presentation/screens/add_transaction_screen.dart';
import 'package:cointally/presentation/screens/select_person_screen.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const BudgetListScreen(),
    const AccountListScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        // If we didn't pop (meaning canPop was false), we redirect to dashboard
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        bottomNavigationBar: BottomAppBar(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white,
          shape: const CircularNotchedRectangle(),
          notchMargin: 10,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 70,
          child: Row(
            children: [
              Expanded(child: _buildNavItem(0, Icons.home_rounded, 'Home')),
              Expanded(child: _buildNavItem(1, Icons.pie_chart_rounded, 'Budgets')),
              const SizedBox(width: 48), // Space for FAB
              Expanded(child: _buildNavItem(2, Icons.account_balance_wallet_rounded, 'Assets')),
              Expanded(child: _buildNavItem(3, Icons.settings_rounded, 'Settings')),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'main_fab',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
            );
          },
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.black,
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.add_rounded, size: 36),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.4),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary 
                  : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
