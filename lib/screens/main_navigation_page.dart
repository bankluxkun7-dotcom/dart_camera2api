import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home/home_page.dart';
import 'scan/scan_medicine_page.dart';
import 'history/history_page.dart';
import 'profile/profile_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _current = 0;
  final _pages = const [
    HomePage(),
    ScanMedicinePage(),
    HistoryPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_current],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F7938),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: _current == 0
                      ? Icons.home_rounded
                      : Icons.home_outlined,
                  label: 'หน้าแรก',
                ),
                _buildNavItem(
                  index: 1,
                  icon: _current == 1
                      ? Icons.camera_alt_rounded
                      : Icons.camera_alt_outlined,
                  label: 'สแกน',
                ),
                _buildNavItem(
                  index: 2,
                  icon: _current == 2
                      ? Icons.history_rounded
                      : Icons.history_outlined,
                  label: 'ประวัติ',
                ),
                _buildNavItem(
                  index: 3,
                  icon: _current == 3
                      ? Icons.person_rounded
                      : Icons.person_outlined,
                  label: 'โปรไฟล์',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _current == index;
    return GestureDetector(
      onTap: () => setState(() => _current = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF10B981)
                  : Colors.white.withOpacity(0.6),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.kanit(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF10B981)
                    : Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
