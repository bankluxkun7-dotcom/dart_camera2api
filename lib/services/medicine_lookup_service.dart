import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/med_item.dart';
import '../repositories/med_repository.dart';

class MedicineLookupService {
  MedicineLookupService({MedRepository? repository})
      : _repository = repository ?? MedRepository();

  final MedRepository _repository;
  final Map<String, Future<MedItem?>> _firestoreCache = {};
  Future<Map<String, MedItem>>? _excelMapFuture;

  Future<MedItem> findMedicine(String name) async {
    final firestoreMed = await _firestoreCache.putIfAbsent(
      name,
      () => _findFromFirestore(name),
    );
    if (firestoreMed != null) return firestoreMed;

    final excelMap = await _loadExcelMap();
    final excelMed = excelMap[name.toLowerCase()];
    if (excelMed != null) return excelMed;

    return _buildFallbackMedicine(name);
  }

  Future<List<MedItem>> findMedicines(List<String> names) async {
    final lookupByName = <String, Future<MedItem>>{};
    return Future.wait(
      names.map((name) {
        return lookupByName.putIfAbsent(name, () => findMedicine(name));
      }),
    );
  }

  Future<Map<String, MedItem>> _loadExcelMap() {
    return _excelMapFuture ??= _createExcelMap();
  }

  Future<Map<String, MedItem>> _createExcelMap() async {
    final allExcelMeds = await _repository.loadAll();
    return {
      for (final med in allExcelMeds) med.name.toLowerCase(): med,
    };
  }

  Future<MedItem?> _findFromFirestore(String name) async {
    try {
      final medDoc = await FirebaseFirestore.instance
          .collection('medicines')
          .doc(name)
          .get();

      if (!medDoc.exists) return null;

      final data = medDoc.data() as Map<String, dynamic>;
      final imagePath = await _resolveImagePath(
        name: name,
        firestoreImagePath: data['imagePath'] ?? '',
      );

      return MedItem(
        name: name,
        description: data['descriptions'] ?? '',
        imagePath: imagePath,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> _resolveImagePath({
    required String name,
    required String firestoreImagePath,
  }) async {
    if (firestoreImagePath.isNotEmpty) return firestoreImagePath;

    final excelMap = await _loadExcelMap();
    return excelMap[name.toLowerCase()]?.imagePath ?? _fallbackImagePath(name);
  }

  MedItem _buildFallbackMedicine(String name) {
    return MedItem(
      name: name,
      description: '',
      imagePath: _fallbackImagePath(name),
    );
  }

  String _fallbackImagePath(String name) {
    final override = kImageOverrides[name];
    if (override != null) return override;

    final sanitized = name
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[\\/:"*?<>|]'), '_');
    return '${MedRepository.imgDir}$sanitized.jpg';
  }
}
