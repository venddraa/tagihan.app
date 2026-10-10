import 'package:flutter/material.dart';

class TagihanVendraApp extends StatelessWidget {
  const TagihanVendraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tagihan Vendra',
      theme: ThemeData(useMaterial3: true),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tagihan Vendra')),
      body: const Center(child: Text('Aplikasi monitoring tagihan pribadi.')),
    );
  }
}
