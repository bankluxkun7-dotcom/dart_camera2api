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

  const ScanResultPage({
    super.key,
    this.imageFile,
    required this.detectedNames,
    this.detectedBboxes = const [],
    this.isFromHistory = false,
    this.cropImagePaths,
  });

  @override
  State<ScanResultPage> createState() => _ScanResultPageState();
}

class _ScanResultPageState extends State<ScanResultPage> {
  late List<bool> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List<bool>.filled(widget.detectedNames.length, true);
  }

  // หายาจาก Firestore
  Future<MedItem?> _findFromFirestore(String name) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final medDoc = await firestore.collection('medicines').doc(name).get();

      if (!medDoc.exists) return null;
      final data = medDoc.data() as Map<String, dynamic>;

      // ถ้าไม่พบ imagePath ให้ไปหาจาก Excel แทน
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
      print('Error searching Firestore: $e');
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

  Future<String?> _cropAndSaveImage(File imageFile, List<double> bbox, String name, {double expandRatio = 1.0, int outputSize = 72}) async {
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
      final resized = img.copyResize(cropped, width: outputSize, height: outputSize);
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'med_crop_${DateTime.now().millisecondsSinceEpoch}_$name.jpg';
      final outPath = '${dir.path}/$fileName';
      final outFile = File(outPath);
      await outFile.writeAsBytes(img.encodeJpg(resized));
      return outPath;
    } catch (e) {
      print('Crop error: $e');
      return null;
    }
  }

  Future<void> _saveHistory(List<String> items) async {
    List<String?> cropPaths = [];
    if (widget.imageFile != null && widget.detectedBboxes.isNotEmpty) {
      for (int i = 0; i < widget.detectedNames.length; i++) {
        if (_selected[i]) {
          final bbox = widget.detectedBboxes.length > i ? widget.detectedBboxes[i] : null;
          if (bbox != null && bbox.length == 4) {
            final path = await _cropAndSaveImage(widget.imageFile!, bbox, widget.detectedNames[i], expandRatio: 1.0, outputSize: 72);
            cropPaths.add(path);
          } else {
            cropPaths.add(null);
          }
        }
      }
    }
    await HistoryStore.addRecord(items, imagePath: widget.imageFile?.path, cropImagePaths: cropPaths);
  }

  Widget croppedImageWidget(
    File imageFile,
    double outputSize,
    List<double> bbox, {
    double expandRatio = 1.0,
  }) {
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
        final squareSize = baseSize * expandRatio;

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
                width: squareSize,
                height: squareSize,
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

  Future<ImageInfo> _getImageInfo(File file) async {
    final completer = Completer<ImageInfo>();
    final img = Image.file(file);
    img.image.resolve(const ImageConfiguration()).addListener(
          ImageStreamListener((info, _) => completer.complete(info)),
        );
    return completer.future;
  }

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
            iconTheme: IconThemeData(color: Colors.white),
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
                if (widget.imageFile != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'รูปภาพที่ใช้ตรวจสอบ',
                      style: GoogleFonts.kanit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Color(0xFF10B981), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF10B981).withOpacity(0.08),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          widget.imageFile!,
                          width: 160,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
                if (!widget.isFromHistory)
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
                for (int i = 0; i < meds.length; i++) ...[
                  GestureDetector(
                    onTap: widget.isFromHistory
                        ? null
                        : () {
                            setState(() {
                              _selected[i] = !_selected[i];
                            });
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: _selected[i]
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFFD1FAE5),
                                  Color(0xFFA7F3D0),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: !_selected[i] ? Colors.white : null,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selected[i]
                              ? const Color(0xFF10B981).withOpacity(0.7)
                              : const Color(0xFFE5E7EB),
                          width: 2,
                        ),
                        boxShadow: [
                          if (_selected[i])
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: widget.isFromHistory && widget.cropImagePaths != null && widget.cropImagePaths!.length > i && widget.cropImagePaths![i] != null
                                    ? Image.file(
                                        File(widget.cropImagePaths![i]!),
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 72,
                                          height: 72,
                                          color: const Color(0xFF10B981)
                                              .withOpacity(.08),
                                          child: const Icon(
                                            Icons.image_not_supported,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      )
                                    : widget.imageFile != null && widget.detectedBboxes.length > i && widget.detectedBboxes[i].length == 4
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
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 72,
                                              height: 72,
                                              color: const Color(0xFF10B981)
                                                  .withOpacity(.08),
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
                                      meds[i].name,
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
                                            borderRadius:
                                                BorderRadius.circular(6),
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
                                                  color:
                                                      const Color(0xFF059669),
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
                                  meds[i].imagePath,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 72,
                                    height: 72,
                                    color: const Color(0xFF10B981)
                                        .withOpacity(.08),
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'สรรพคุณยา',
                              style: GoogleFonts.kanit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 4),
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
                              meds[i].description.isEmpty
                                  ? 'ไม่มีข้อมูลสรรพคุณ'
                                  : meds[i].description,
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
                  ),
                ],
              ],
            ),
          ),
          bottomNavigationBar: widget.isFromHistory
              ? null
              : Padding(
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
                        final selectedNames = <String>[];
                        for (int i = 0; i < meds.length; i++) {
                          if (_selected[i]) selectedNames.add(meds[i].name);
                        }
                        if (selectedNames.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'กรุณาเลือกยาที่ต้องการบันทึก',
                                style: GoogleFonts.kanit(),
                              ),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        await _saveHistory(selectedNames);
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
                        '',
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
