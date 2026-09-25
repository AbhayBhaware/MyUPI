// lib/screens/shell_page.dart
//
// Main Navigation Shell for MyUPI Soundbox.
// ------------------------------------------
// Shown post-authentication and post-setup.
// Tabs:
// 0: Home     — Soundbox dashboard & real-time feed
// 1: History  — Payment ledger with search & filters
// 2: Settings — Soundbox speech, merchant name & account settings

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class ShellPage extends StatefulWidget {
  final int initialIndex;
  const ShellPage({super.key, this.initialIndex = 0});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  late int _selectedIndex = widget.initialIndex;

  void _navigateToTab(int index) {
    if (mounted) setState(() => _selectedIndex = index);
  }

  late final List<Widget> _pages = [
    HomeScreen(onNavigateToTab: _navigateToTab),
    const HistoryScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.cardBorder, width: 1.0),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            setState(() => _selectedIndex = i);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.speaker_outlined),
              selectedIcon: Icon(Icons.speaker),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
