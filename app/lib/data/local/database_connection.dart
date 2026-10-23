import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';

AppDatabase openAppDatabase() {
  const name = String.fromEnvironment(
    'TAGIHAN_DATABASE_NAME',
    defaultValue: 'tagihan_vendra',
  );
  if (!RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(name)) {
    throw StateError(
      'TAGIHAN_DATABASE_NAME harus berupa huruf kecil, angka, atau underscore.',
    );
  }
  return AppDatabase(
    driftDatabase(
      name: name,
      native: DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    ),
  );
}
