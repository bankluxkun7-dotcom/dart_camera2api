import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Future<void> logMedicineWithBrands(String medicineName) async {
  final db = FirebaseFirestore.instance;
  final medicineDoc = await db.collection('medicines').doc(medicineName).get();

  if (!medicineDoc.exists) return;

  debugPrint(medicineDoc['descriptions'].toString());

  final brandSnapshot = await db
      .collection('medicines')
      .doc(medicineName)
      .collection('brands')
      .get();

  for (final brand in brandSnapshot.docs) {
    debugPrint(brand.id);
    debugPrint(brand['color'].toString());
    debugPrint(brand['engraved'].toString());
    debugPrint(brand['form'].toString());
  }
}
