import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ScanResultHeader extends StatelessWidget {
  const ScanResultHeader({
    super.key,
    required this.imageFile,
    required this.showSelectionAction,
    required this.selectedCountListenable,
    required this.totalCount,
    required this.onToggleSelectAll,
  });

  final File? imageFile;
  final bool showSelectionAction;
  final ValueListenable<int> selectedCountListenable;
  final int totalCount;
  final VoidCallback onToggleSelectAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageFile != null) ...[
          Text(
            'รูปภาพที่ใช้ตรวจสอบ',
            style: GoogleFonts.kanit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                imageFile!,
                width: 160,
                height: 160,
                fit: BoxFit.cover,
                cacheWidth: 320,
                cacheHeight: 320,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (showSelectionAction)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ValueListenableBuilder<int>(
              valueListenable: selectedCountListenable,
              builder: (context, selectedCount, _) {
                final allSelected =
                    totalCount > 0 && selectedCount == totalCount;
                return Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: onToggleSelectAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      icon: Icon(
                        allSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                      ),
                      label: Text(
                        allSelected ? 'ยกเลิกเลือกทั้งหมด' : 'เลือกทั้งหมด',
                        style: GoogleFonts.kanit(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
