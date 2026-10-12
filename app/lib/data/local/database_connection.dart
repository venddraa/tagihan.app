import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';

AppDatabase openAppDatabase() {
  return AppDatabase(
    driftDatabase(
      name: 'tagihan_vendra',
      native: DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    ),
  );
}
