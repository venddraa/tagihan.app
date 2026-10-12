import 'package:flutter/material.dart';
import 'package:tagihan_vendra/app/app_shell.dart';
import 'package:tagihan_vendra/app/app_theme.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';

class TagihanVendraApp extends StatelessWidget {
  const TagihanVendraApp({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tagihan Vendra',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: AppShell(database: database),
    );
  }
}
