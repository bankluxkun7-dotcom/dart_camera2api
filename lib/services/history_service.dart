import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_record.dart';

/// การจัดการประวัติการสแกนด้วย SharedPreferences
class HistoryStore {
  static const _key = 'scan_history';

  /// โหลดบันทึกประวัติทั้งหมดจัดเรียงตามล่าสุดก่อน
  static Future<List<HistoryRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];

    final list = (jsonDecode(raw) as List)
        .map((e) => HistoryRecord.fromJson(e))
        .toList();
    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  /// เพิ่มบันทึกใหม่ลงในประวัติ
  static Future<void> addRecord(List<String> items, {String? imagePath}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await load();
    list.insert(0, HistoryRecord(time: DateTime.now(), items: items, imagePath: imagePath));
    await prefs.setString(
      _key,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  /// ลบบันทึกประวัติทั้งหมด
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
