import 'package:excel/excel.dart' as xlsx;
import 'package:flutter/services.dart' show rootBundle;
import '../models/med_item.dart';

const Map<String, String> kImageOverrides = <String, String>{};

/// ที่เก็บข้อมูลสำหรับการโหลดและแคชข้อมูลยาจากไฟล์ Excel
class MedRepository {
  static const String excelAsset = 'assets/data/meds.xlsm';
  static const String imgDir = 'assets/images/amldac/';

  List<MedItem>? _cache;

  /// แปลงชื่อเป็นชื่อไฟล์ฐาน: เว้นวรรค -> "_" อักขระต้องห้าม -> "_"
  String _fileBase(String name) {
    var s = name.trim();
    s = s.replaceAll(RegExp(r'\s+'), '_');
    s = s.replaceAll(RegExp(r'[\\/:"*?<>|]'), '_');
    return s;
  }

  /// โหลดยาทั้งหมดจากไฟล์ Excel พร้อมแคช
  Future<List<MedItem>> loadAll() async {
    if (_cache != null) return _cache!;

    final bytes = (await rootBundle.load(excelAsset)).buffer.asUint8List();
    final book = xlsx.Excel.decodeBytes(bytes);
    final sheet = book.tables.values.first;

    // แยกแถวส่วนหัว
    final headers = sheet
        .row(0)
        .map((c) => (c?.value?.toString() ?? '').trim())
        .toList();
    
    int idxOf(String h) =>
        headers.indexWhere((x) => x.toLowerCase() == h.toLowerCase());

    final idxName = idxOf('ชื่อยาความดันโลหิตสูง(ยี่ห้อยา_ชื่อยา)');
    final idxDesc = idxOf('สรรพคุณ');

    final out = <MedItem>[];
    for (int r = 1; r < sheet.maxRows && out.length < 36; r++) {
      final row = sheet.row(r);
      String cell(int i) => (i >= 0 && i < row.length && row[i] != null)
          ? row[i]!.value.toString().trim()
          : '';

      final name = cell(idxName);
      final desc = cell(idxDesc);
      if (name.isEmpty && desc.isEmpty) continue;

      final base = _fileBase(name);
      final path = kImageOverrides[name] ?? '$imgDir$base.jpg';

      out.add(MedItem(name: name, description: desc, imagePath: path));
    }

    return _cache = out;
  }
}
