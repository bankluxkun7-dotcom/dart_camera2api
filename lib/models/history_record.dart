/// โมเดลการบันทึกประวัติการสแกนยา
class HistoryRecord {
  final DateTime time;
  final List<String> items;
  final String? imagePath;

  HistoryRecord({
    required this.time,
    required this.items,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'items': items,
    'imagePath': imagePath,
  };

  static HistoryRecord fromJson(Map<String, dynamic> json) => HistoryRecord(
    time: DateTime.parse(json['time']),
    items: (json['items'] as List).cast<String>(),
    imagePath: json['imagePath'] as String?,
  );
}
