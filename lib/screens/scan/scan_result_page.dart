import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/med_item.dart';
import '../../repositories/med_repository.dart';
import '../../services/history_service.dart';

class ScanResultPage extends StatelessWidget {
  final File? imageFile;
  final String detectedName;

  const ScanResultPage({
    super.key,
    this.imageFile,
    required this.detectedName,
  });

  // หายาจาก Firestore
  Future<MedItem?> _findFromFirestore() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final medDoc = await firestore
          .collection('medicines')
          .doc(detectedName)
          .get();
      
      if (!medDoc.exists) return null;
      final data = medDoc.data() as Map<String, dynamic>;

      //ถ้าไม่พบ imagePath ให้ไปหาจาก Excel แทน
      String imagePath = data['imagePath'] ?? '';
      if (imagePath.isEmpty) {
        final excelMed = await _findFromExcel();
        imagePath = excelMed?.imagePath ?? '';
      }

      return MedItem(
        name: detectedName,
        description: data['descriptions'] ?? '',
        imagePath: imagePath,
      );
    } catch (e) {
      print('Error searching Firestore: $e');
    }
    return null;
  }

  Future<MedItem?> _findFromExcel() async {
    final repo = MedRepository();
    final all = await repo.loadAll();
    return all.firstWhere(
      (m) => m.name.toLowerCase() == detectedName.toLowerCase(),
      orElse: () {
        String sanitize(String x) {
          var s = x.trim();
          s = s.replaceAll(RegExp(r'\s+'), '_');
          s = s.replaceAll(RegExp(r'[\\/:"*?<>|]'), '_');
          return s;
        }

        final base = sanitize(detectedName);
        final override = kImageOverrides[detectedName];
        return MedItem(
          name: detectedName,
          description: '',
          imagePath: override ?? 'assets/images/amldac/$base.jpg',
        );
      },
    );
  }

  Future<MedItem?> _findMedicine() async {
    // หาจาก Firestore ก่อน
    final firestoreMed = await _findFromFirestore();
    if (firestoreMed != null) {
      return firestoreMed;
    }

    // ถ้าไม่เจอ ให้หาจาก Excel
    return _findFromExcel();
  }

  Future<void> _saveHistory(List<String> items) async {
    await HistoryStore.addRecord(items, imagePath: imageFile?.path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MedItem?>(
      future: _findMedicine(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final med = snap.data!;
        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F7938),
            elevation: 0,
            title: Text(
              'ผลลัพธ์การสแกน',
              style: GoogleFonts.kanit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFD1FAE5),
                        Color(0xFFA7F3D0),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageFile != null
                            ? Image.file(
                                imageFile!,
                                width: 86,
                                height: 86,
                                fit: BoxFit.cover,
                              )
                            : Image.asset(
                                med.imagePath,
                                width: 86,
                                height: 86,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 86,
                                  height: 86,
                                  color: const Color(0xFF10B981).withOpacity(.08),
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ระบุยาได้สำเร็จ',
                              style: GoogleFonts.kanit(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              med.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.kanit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 14,
                                        color: Color(0xFF10B981),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'ยืนยันแล้ว',
                                        style: GoogleFonts.kanit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          med.imagePath,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            color: const Color(0xFF10B981).withOpacity(.08),
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'สรรพคุณยา',
                  style: GoogleFonts.kanit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    med.description.isEmpty
                        ? 'ไม่มีข้อมูลสรรพคุณ'
                        : med.description,
                    style: GoogleFonts.kanit(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF374151),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF059669),
                    Color(0xFF10B981),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: () async {
                  await _saveHistory([med.name]);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'บันทึกลง History แล้ว',
                          style: GoogleFonts.kanit(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor: const Color(0xFF059669),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save_alt_rounded),
                label: Text(
                  'บันทึกลง History',
                  style: GoogleFonts.kanit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
