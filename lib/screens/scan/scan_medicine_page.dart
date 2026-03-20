import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/scan_api_service.dart';
import 'full_screen_camera_preview.dart';

const MethodChannel _cameraChannel = MethodChannel('dart_camera2api/camera');

class ScanMedicinePage extends StatefulWidget {
  const ScanMedicinePage({super.key});

  @override
  State<ScanMedicinePage> createState() => _ScanMedicinePageState();
}

class _ScanMedicinePageState extends State<ScanMedicinePage> {
  static const String _autosavePreferenceKey = 'scan_autosave_enabled';

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();

  File? _image;
  bool _autosaveEnabled = true;

  Future<void> _takePhoto() async {
    try {
      final status = await Permission.camera.request();
      if (status.isDenied) {
        _showSnackBar('สิทธิ์การใช้กล้องถูกปฏิเสธ');
        return;
      }

      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return;
      }

      final initResult = await _cameraChannel.invokeMethod('init');
      if (!mounted) return;

      if (initResult is! int) {
        _showSnackBar('ไม่สามารถเปิดกล้องได้: $initResult');
        return;
      }

      final path = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenCameraPreview(textureId: initResult),
          fullscreenDialog: true,
        ),
      );

      if (!mounted) return;
      if (path != null && path.isNotEmpty) {
        setState(() => _image = File(path));
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showSnackBar('ข้อผิดพลาดของกล้อง: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('ข้อผิดพลาดที่ไม่คาดคิด: $error');
    }
  }

  Future<void> _pickGallery() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (!mounted || image == null) return;
    setState(() => _image = File(image.path));
  }

  Future<void> _goToResult() async {
    if (_image == null) {
      _showSnackBar('โปรดถ่ายรูปหรือเลือกภาพยาก่อนดูผลลัพธ์');
      return;
    }

    await sendImageAndShowResult(
      context: context,
      image: _image!,
      nameController: _nameController,
      autosave: _autosaveEnabled,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAutosavePreference();
  }

  Future<void> _loadAutosavePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final autosave = prefs.getBool(_autosavePreferenceKey) ?? true;
    if (!mounted) return;
    setState(() => _autosaveEnabled = autosave);
  }

  Future<void> _setAutosaveEnabled(bool value) async {
    setState(() => _autosaveEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autosavePreferenceKey, value);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.kanit()),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF112C63),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'สแกนระบุชื่อยา',
          style: GoogleFonts.kanit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            height: 120,
            decoration: const BoxDecoration(
              color: Color(0xFF112C63),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const _ScanIntroCard(),
                  const SizedBox(height: 24),
                  _ScanModeCard(
                    autosaveEnabled: _autosaveEnabled,
                    onChanged: _setAutosaveEnabled,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          onTap: _takePhoto,
                          icon: Icons.camera_alt_rounded,
                          label: 'เปิดกล้องถ่าย',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          onTap: _pickGallery,
                          icon: Icons.photo_library_rounded,
                          label: 'เลือกจากเครื่อง',
                        ),
                      ),
                    ],
                  ),
                  if (_image != null) ...[
                    const SizedBox(height: 24),
                    _SelectedImagePreview(
                      image: _image!,
                      onRemove: () => setState(() => _image = null),
                    ),
                  ],
                  const SizedBox(height: 32),
                  _AnalyzeButton(onPressed: _goToResult),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanIntroCard extends StatelessWidget {
  const _ScanIntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
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
    );
  }
}

class _ScanModeCard extends StatelessWidget {
  const _ScanModeCard({
    required this.autosaveEnabled,
    required this.onChanged,
  });

  final bool autosaveEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'โหมดบันทึกประวัติ',
                  style: GoogleFonts.kanit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  autosaveEnabled
                      ? 'บันทึกอัตโนมัติทันทีหลังสแกนเสร็จ'
                      : 'เลือกเฉพาะยาที่ต้องการก่อนค่อยบันทึก',
                  style: GoogleFonts.kanit(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: autosaveEnabled,
            activeThumbColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.35),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.2),
          ),
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
}

class _SelectedImagePreview extends StatelessWidget {
  const _SelectedImagePreview({
    required this.image,
    required this.onRemove,
  });

  final File image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              image,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              cacheWidth: 720,
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onRemove,
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
    );
  }
}

class _AnalyzeButton extends StatelessWidget {
  const _AnalyzeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F7938), Color(0xFF10B981)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: onPressed,
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
    );
  }
}
