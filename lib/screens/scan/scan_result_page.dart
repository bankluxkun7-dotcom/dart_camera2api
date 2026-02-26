import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/med_item.dart';
import '../../repositories/med_repository.dart';
import '../../services/history_service.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ScanResultPage extends StatefulWidget {
  final File? imageFile;
  final List<String> detectedNames;
  final List<List<double>> detectedBboxes;
  final bool isFromHistory;
  final List<String?>? cropImagePaths;
  final bool autosave;

  const ScanResultPage({
    super.key,
    this.imageFile,
    required this.detectedNames,
    this.detectedBboxes = const [],
    this.isFromHistory = false,
    this.cropImagePaths,
    this.autosave = true, //แก้ตรงนี้เพื่อเปิด/ปิดการบันทึกอัตโนมัติในประวัติ true = บันทึกอัตโนมัติ, false = ไม่บันทึกอัตโนมัติ
  });

  @override
  State<ScanResultPage> createState() => _ScanResultPageState();
}

class _ScanResultPageState extends State<ScanResultPage> {
    bool _historySaved = false;
  late List<bool> _selected;
  late List<bool> _isExpanded;

  @override
  void initState() {
    super.initState();
    _selected = List<bool>.filled(widget.detectedNames.length, true);
    _isExpanded = List<bool>.filled(widget.detectedNames.length, false);
    if (widget.autosave && !widget.isFromHistory && widget.detectedNames.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!_historySaved) {
          final meds = await _findMedicines();
          final selectedNames = <String>[];
          for (int i = 0; i < meds.length; i++) {
            if (_selected[i]) {
              selectedNames.add(meds[i].name);
            }
          }
          if (selectedNames.isNotEmpty) {
            await _saveHistory(selectedNames);
            if (mounted) {
              setState(() => _historySaved = true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'บันทึกลง History แล้ว',
                    style: GoogleFonts.kanit(),
                  ),
                  backgroundColor: const Color(0xFF059669),
                ),
              );
            }
          }
        }
      });
    }
  }

  // ================= FIRESTORE =================

  Future<MedItem?> _findFromFirestore(String name) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final medDoc = await firestore.collection('medicines').doc(name).get();

      if (!medDoc.exists) return null;
      final data = medDoc.data() as Map<String, dynamic>;

      String imagePath = data['imagePath'] ?? '';
      if (imagePath.isEmpty) {
        final excelMed = await _findFromExcel(name);
        imagePath = excelMed?.imagePath ?? '';
      }

      return MedItem(
        name: name,
        description: data['descriptions'] ?? '',
        imagePath: imagePath,
      );
    } catch (e) {
      debugPrint('Error searching Firestore: $e');
    }
    return null;
  }

  Future<MedItem?> _findFromExcel(String name) async {
    final repo = MedRepository();
    final all = await repo.loadAll();
    return all.firstWhere(
      (m) => m.name.toLowerCase() == name.toLowerCase(),
      orElse: () {
        String sanitize(String x) {
          var s = x.trim();
          s = s.replaceAll(RegExp(r'\s+'), '_');
          s = s.replaceAll(RegExp(r'[\\/:"*?<>|]'), '_');
          return s;
        }

        final base = sanitize(name);
        final override = kImageOverrides[name];
        return MedItem(
          name: name,
          description: '',
          imagePath: override ?? 'assets/images/amldac/$base.jpg',
        );
      },
    );
  }

  Future<List<MedItem>> _findMedicines() async {
    List<MedItem> meds = [];
    for (final name in widget.detectedNames) {
      MedItem? med = await _findFromFirestore(name);
      med ??= await _findFromExcel(name);
      meds.add(med!);
    }
    return meds;
  }

  // ================= CROP =================

  Future<String?> _cropAndSaveImage(
    File imageFile,
    List<double> bbox,
    String name, {
    double expandRatio = 1.0,
    int outputSize = 72,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) return null;

      final imgW = original.width.toDouble();
      final imgH = original.height.toDouble();
      final x1 = bbox[0].clamp(0, imgW);
      final y1 = bbox[1].clamp(0, imgH);
      final x2 = bbox[2].clamp(0, imgW);
      final y2 = bbox[3].clamp(0, imgH);

      final cropW = (x2 - x1).abs();
      final cropH = (y2 - y1).abs();
      final baseSize = math.max(cropW, cropH);
      final squareSize = baseSize * expandRatio;
      final centerX = x1 + cropW / 2;
      final centerY = y1 + cropH / 2;

      double newX1 = centerX - squareSize / 2;
      double newY1 = centerY - squareSize / 2;

      newX1 = newX1.clamp(0, imgW - squareSize);
      newY1 = newY1.clamp(0, imgH - squareSize);

      final cropped = img.copyCrop(
        original,
        x: newX1.toInt(),
        y: newY1.toInt(),
        width: squareSize.toInt(),
        height: squareSize.toInt(),
      );

      final resized =
          img.copyResize(cropped, width: outputSize, height: outputSize);

      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'med_crop_${DateTime.now().millisecondsSinceEpoch}_$name.jpg';
      final outPath = '${dir.path}/$fileName';

      final outFile = File(outPath);
      await outFile.writeAsBytes(img.encodeJpg(resized));
      return outPath;
    } catch (e) {
      debugPrint('Crop error: $e');
      return null;
    }
  }

  Future<void> _saveHistory(List<String> items) async {
    List<String?> cropPaths = [];

    if (widget.imageFile != null && widget.detectedBboxes.isNotEmpty) {
      for (int i = 0; i < widget.detectedNames.length; i++) {
        if (_selected[i]) {
          final bbox = widget.detectedBboxes.length > i
              ? widget.detectedBboxes[i]
              : null;

          if (bbox != null && bbox.length == 4) {
            final path = await _cropAndSaveImage(
              widget.imageFile!,
              bbox,
              widget.detectedNames[i],
            );
            cropPaths.add(path);
          } else {
            cropPaths.add(null);
          }
        }
      }
    }

    await HistoryStore.addRecord(
      items,
      imagePath: widget.imageFile?.path,
      cropImagePaths: cropPaths,
    );
  }

  // ================= IMAGE INFO =================

  Future<ImageInfo> _getImageInfo(File file) async {
    final completer = Completer<ImageInfo>();
    final imgWidget = Image.file(file);

    imgWidget.image.resolve(const ImageConfiguration()).addListener(
          ImageStreamListener((info, _) => completer.complete(info)),
        );

    return completer.future;
  }

  Widget croppedImageWidget(
    File imageFile,
    double outputSize,
    List<double> bbox,
  ) {
    return FutureBuilder<ImageInfo>(
      future: _getImageInfo(imageFile),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final info = snapshot.data!;
        final imgW = info.image.width.toDouble();
        final imgH = info.image.height.toDouble();

        final x1 = bbox[0].clamp(0, imgW);
        final y1 = bbox[1].clamp(0, imgH);
        final x2 = bbox[2].clamp(0, imgW);
        final y2 = bbox[3].clamp(0, imgH);

        final cropW = (x2 - x1).abs();
        final cropH = (y2 - y1).abs();

        final baseSize = math.max(cropW, cropH);
        final squareSize = baseSize;

        final centerX = x1 + cropW / 2;
        final centerY = y1 + cropH / 2;

        double newX1 = centerX - squareSize / 2;
        double newY1 = centerY - squareSize / 2;

        newX1 = newX1.clamp(0, imgW - squareSize);
        newY1 = newY1.clamp(0, imgH - squareSize);

        return SizedBox(
          width: outputSize,
          height: outputSize,
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: squareSize.toDouble(),
                height: squareSize.toDouble(),
                child: Stack(
                  children: [
                    Positioned(
                      left: -newX1,
                      top: -newY1,
                      child: Image.file(
                        imageFile,
                        width: imgW,
                        height: imgH,
                        fit: BoxFit.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MedItem>>(
      future: _findMedicines(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final meds = snap.data!;

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: AppBar(
            backgroundColor: const Color(0xFF112C63),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
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

          // ================= BODY =================

          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== IMAGE PREVIEW =====

                if (widget.imageFile != null) ...[
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
                        widget.imageFile!,
                        width: 160,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // โค๊ดปุ่มยกเลิกเลือกทั้งหมด สามารถปรับแต่งตรงนี้ได้เลย ถ้าไม่ใช่ก็ลบออกได้เลย
                if (!widget.isFromHistory && !widget.autosave)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          icon: Icon(_selected.every((v) => v)
                              ? Icons.check_box
                              : Icons.check_box_outline_blank),
                          label: Text(
                            _selected.every((v) => v)
                                ? 'ยกเลิกเลือกทั้งหมด'
                                : 'เลือกทั้งหมด',
                            style: GoogleFonts.kanit(
                                fontWeight: FontWeight.w500, fontSize: 15),
                          ),
                          onPressed: () {
                            setState(() {
                              final selectAll = !_selected.every((v) => v);
                              for (int i = 0; i < _selected.length; i++) {
                                _selected[i] = selectAll;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                // โค๊ดปุ่มถึงตรงนี้

                // ===== LIST =====

                for (int i = 0; i < meds.length; i++) ...[
                  GestureDetector(
                    onTap: widget.isFromHistory
                        ? null
                        : () {
                            setState(() => _selected[i] = !_selected[i]);
                          },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selected[i]
                            ? const Color(0xFFD1FAE5)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF10B981),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                child: widget.isFromHistory &&
                                        widget.cropImagePaths != null &&
                                        widget.cropImagePaths!.length > i &&
                                        widget.cropImagePaths![i] != null
                                    ? Image.file(
                                        File(widget.cropImagePaths![i]!),
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                      )
                                    : widget.imageFile != null &&
                                            widget.detectedBboxes.length > i &&
                                            widget.detectedBboxes[i].length == 4
                                        ? croppedImageWidget(
                                            widget.imageFile!,
                                            72,
                                            widget.detectedBboxes[i],
                                          )
                                        : Image.asset(
                                            meds[i].imagePath,
                                            width: 72,
                                            height: 72,
                                            fit: BoxFit.cover,
                                          ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  meds[i].name,
                                  style: GoogleFonts.kanit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ClipRRect(
                                child: Image.asset(
                                  meds[i].imagePath,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // ===== EXPAND BUTTON =====

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'สรรพคุณยา',
                                style: GoogleFonts.kanit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _isExpanded[i]
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: const Color(0xFF10B981),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isExpanded[i] = !_isExpanded[i];
                                  });
                                },
                              ),
                            ],
                          ),

                          // ===== DESCRIPTION =====

                          AnimatedCrossFade(
                            firstChild: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Text(
                                meds[i].description.isEmpty
                                    ? 'ไม่มีข้อมูลสรรพคุณ'
                                    : meds[i].description,
                                style: GoogleFonts.kanit(height: 1.6),
                              ),
                            ),
                            secondChild: const SizedBox.shrink(),
                            crossFadeState: _isExpanded[i]
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            duration: const Duration(milliseconds: 250),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ================= SAVE BUTTON =================

          bottomNavigationBar: widget.isFromHistory
              ? null
              : (widget.autosave ? null : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: FilledButton.icon(
                    onPressed: () async {
                      final selectedNames = <String>[];
                      for (int i = 0; i < meds.length; i++) {
                        if (_selected[i]) {
                          selectedNames.add(meds[i].name);
                        }
                      }

                      if (selectedNames.isEmpty) return;

                      await _saveHistory(selectedNames);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'บันทึกลง History แล้ว',
                              style: GoogleFonts.kanit(),
                            ),
                            backgroundColor: const Color(0xFF059669),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.save_alt_rounded),
                    label: Text(
                      'บันทึก History',
                      style: GoogleFonts.kanit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                )),
        );
      },
    );
  }
}
