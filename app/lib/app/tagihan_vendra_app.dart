import 'package:flutter/material.dart';
import 'package:tagihan_vendra/app/app_shell.dart';
import 'package:tagihan_vendra/app/app_theme.dart';

class TagihanVendraApp extends StatelessWidget {
  const TagihanVendraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tagihan Vendra',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}
