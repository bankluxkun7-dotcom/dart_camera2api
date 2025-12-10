import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'full_screen_camera_preview.dart';
import '../../services/scan_api_service.dart';

const MethodChannel _cameraChannel = MethodChannel('dart_camera2api/camera');

class ScanMedicinePage extends StatefulWidget {
  const ScanMedicinePage({super.key});

  @override
  State<ScanMedicinePage> createState() => _ScanMedicinePageState();
}

class _ScanMedicinePageState extends State<ScanMedicinePage> {
  final _picker = ImagePicker();
  File? _image;
  final _nameController = TextEditingController();

  Future<void> _takePhoto() async {
    try {
      final status = await Permission.camera.request();
      if (status.isDenied) {
        _showSnackBar('สิทธิ์การใช้กล้องถูกปฏิเสธ');
        return;
      }
      if (status.isPermanentlyDenied) {
        openAppSettings();
        return;
      }

      final initResult = await _cameraChannel.invokeMethod('init');
      if (initResult is int) {
        final textureId = initResult;
        final path = await Navigator.push<String?>(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenCameraPreview(textureId: textureId),
            fullscreenDialog: true,
          ),
        );

        if (path != null && path.isNotEmpty) setState(() => _image = File(path));
      } else {
        _showSnackBar('ไม่สามารถเปิดกล้องได้: $initResult');
      }
    } on PlatformException catch (e) {
      _showSnackBar('ข้อผิดพลาดของกล้อง: ${e.message}');
    } catch (e) {
      _showSnackBar('ข้อผิดพลาดที่ไม่คาดคิด: $e');
    }
  }

  Future<void> _pickGallery() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _image = File(x.path));
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.kanit())),
    );
  }

  Future<void> _goResult() async {
    if (_image == null) {
      _showSnackBar('โปรดถ่ายรูปหรือเลือกภาพยาก่อนดูผลลัพธ์');
      return;
    }
    await sendImageAndShowResult(
      context: context,
      image: _image!,
      nameController: _nameController,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7938),
        elevation: 0,
        title: Text(
          'สแกนระบุชื่อยา',
          style: GoogleFonts.kanit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            height: 120,
            decoration: const BoxDecoration(
              color: Color(0xFF0F7938),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.medication_rounded,
                            size: 40,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ค้นหาข้อมูลยาด้วยรูปภาพ',
                          style: GoogleFonts.kanit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ถ่ายรูปตัวยาให้มีขนาดใหญ่ชัดเจน\nเพื่อให้ AI วิเคราะห์ข้อมูลได้แม่นยำ',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.kanit(
                            fontSize: 14,
                            color: const Color(0xFF6B7280),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          onTap: _takePhoto,
                          icon: Icons.camera_alt_rounded,
                          label: 'เปิดกล้องถ่าย',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _actionButton(
                          onTap: _pickGallery,
                          icon: Icons.photo_library_rounded,
                          label: 'เลือกจากเครื่อง',
                        ),
                      ),
                    ],
                  ),
                  if (_image != null) ...[
                    const SizedBox(height: 24),
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              _image!,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _image = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F7938), Color(0xFF10B981)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: _goResult,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'วิเคราะห์ภาพยา',
                          style: GoogleFonts.kanit(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required VoidCallback onTap, required IconData icon, required String label}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF10B981), size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.kanit(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
