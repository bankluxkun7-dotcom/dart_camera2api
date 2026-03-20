import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../screens/scan/scan_result_page.dart';

Future<Map<String, dynamic>> sendImageToApi(File image) async {
  final uri = Uri.parse('http://76.13.217.248:8080/detect/');
  final request = http.MultipartRequest('POST', uri);
  request.files.add(await http.MultipartFile.fromPath('file', image.path));

  final streamed = await request.send();
  final response = await http.Response.fromStream(streamed);

  if (response.statusCode != 200) {
    throw Exception('Upload failed: ${response.statusCode}');
  }

  return json.decode(response.body) as Map<String, dynamic>;
}

List<double> _parseBbox(dynamic value) {
  final rawList = value is List ? value : const <dynamic>[];
  final numbers = rawList
      .whereType<num>()
      .map((item) => item.toDouble())
      .toList();

  if (numbers.length >= 4) return numbers.take(4).toList();
  return [...numbers, ...List<double>.filled(4 - numbers.length, 0.0)];
}

Future<void> _saveResultsToFirestore(Map<String, dynamic> data) async {
  try {
    final timestamp = DateTime.now().toUtc();
    await FirebaseFirestore.instance
        .collection('results')
        .doc(timestamp.toIso8601String())
        .set({
      'timestamp': timestamp,
      'data': data,
    });
  } catch (error) {
    debugPrint('Error saving to Firestore: $error');
  }
}

List<dynamic> _extractDetections(Map<String, dynamic> body) {
  return (body['detection_data']?['detections'] ?? []) as List<dynamic>;
}

List<String> _extractDetectedNames(
  List<dynamic> detections,
  TextEditingController nameController,
) {
  return detections
      .map(
        (detection) =>
            (detection['class'] ?? nameController.text.trim()).toString(),
      )
      .toList();
}

List<List<double>> _extractDetectedBboxes(List<dynamic> detections) {
  return detections.map((detection) => _parseBbox(detection['bbox'])).toList();
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

Future<void> sendImageAndShowResult({
  required BuildContext context,
  required File image,
  required TextEditingController nameController,
  required bool autosave,
}) async {
  try {
    final body = await sendImageToApi(image);
    if (!context.mounted) return;
    final status = body['status'] ?? '';

    if (status != 'success') {
      final detail = body['detail'] ?? json.encode(body);
      _showSnackBar(context, 'Server error: $detail');
      return;
    }

    final detections = _extractDetections(body);
    if (detections.isEmpty) {
      _showSnackBar(context, 'ตรวจไม่พบยาในภาพ');
      return;
    }

    detections.sort((a, b) {
      final left = (a['confidence'] ?? 0) as num;
      final right = (b['confidence'] ?? 0) as num;
      return right.compareTo(left);
    });

    final detectedNames = _extractDetectedNames(detections, nameController);
    final detectedBboxes = _extractDetectedBboxes(detections);

    unawaited(_saveResultsToFirestore(body));

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanResultPage(
          imageFile: image,
          detectedNames: detectedNames,
          detectedBboxes: detectedBboxes,
          autosave: autosave,
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    _showSnackBar(context, 'อัปโหลดผิดพลาด: $error');
  }
}
