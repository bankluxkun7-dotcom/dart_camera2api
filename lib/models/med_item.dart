/// โมเดลรายการยา
class MedItem {
  final String name;        // ชื่อยาความดันโลหิตสูง(ยี่ห้อยา_ชื่อยา)
  final String description; // สรรพคุณ
  final String imagePath;   // พาธภาพ: assets/images/amldac/<sanitized>.jpg

  MedItem({
    required this.name,
    required this.description,
    required this.imagePath,
  });
}
