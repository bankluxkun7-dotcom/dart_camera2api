import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/scan/scan_result_page.dart';

Future<Map<String, dynamic>> sendImageToApi(File image) async {
  final uri = Uri.parse('http://192.168.1.110:8080/detect/');
  final request = http.MultipartRequest('POST', uri);
  request.files.add(await http.MultipartFile.fromPath('file', image.path));

  final streamed = await request.send();
  final resp = await http.Response.fromStream(streamed);

  if (resp.statusCode != 200) {
    throw Exception('Upload failed: ${resp.statusCode}');
  }

  final Map<String, dynamic> body = json.decode(resp.body) as Map<String, dynamic>;
  return body;
}

List<double> _parseBbox(dynamic value) {
  final rawList = value is List ? value : const <dynamic>[];
  final nums = rawList
      .where((v) => v is num)
      .map((v) => (v as num).toDouble())
      .toList();
  if (nums.length >= 4) return nums.take(4).toList();
  return [...nums, ...List<double>.filled(4 - nums.length, 0.0)];
}

Future<void> _saveResultsToFirestore(Map<String, dynamic> data) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final timestamp = DateTime.now().toUtc();
    final timestampString = timestamp.toIso8601String();

    await firestore
        .collection('results')
        .doc(timestampString)
        .set({
          'timestamp': timestamp,
          'data': data,
        });
  } catch (e) {
    print('Error saving to Firestore: $e');
  }
}

Future<void> sendImageAndShowResult({
  required BuildContext context,
  required File image,
  required TextEditingController nameController,
}) async {
  try {
    final body = await sendImageToApi(image);

    final String status = body['status'] ?? '';
    if (status == 'success') {
      final List detections = (body['detection_data']?['detections'] ?? []) as List;
      if (detections.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ตรวจไม่พบยาในภาพ')),
        );
        return;
      }

      // เรียงลำดับการตรวจจับตามความมั่นใจจากมากไปน้อย
      detections.sort((a, b) {
        final na = (a['confidence'] ?? 0) as num;
        final nb = (b['confidence'] ?? 0) as num;
        return nb.compareTo(na);
      });

      // ดึงชื่อที่ตรวจจับได้
      final List<String> detectedNames = detections
          .map((d) => (d['class'] ?? nameController.text.trim()).toString())
          .toList();

      final List<List<double>> detectedBboxes = detections
          .map((d) => _parseBbox(d['bbox']))
          .toList();

      await _saveResultsToFirestore(body);

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScanResultPage( //ถ้าจะทดสอบแสดงกรอบพร้อมชื่อยาให้แก้เป็น TestOverlay
              imageFile: image,
              detectedNames: detectedNames,
              detectedBboxes: detectedBboxes,
            ),
          ),
        );
      }
    } else {
      final detail = body['detail'] ?? json.encode(body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Server error: $detail')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('อัพโหลดผิดพลาด: $e')),
    );
  }
}
