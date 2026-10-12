import 'package:flutter/widgets.dart';
import 'package:tagihan_vendra/app/tagihan_vendra_app.dart';
import 'package:tagihan_vendra/data/local/database_connection.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(TagihanVendraApp(database: openAppDatabase()));
}
