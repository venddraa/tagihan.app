import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/app/tagihan_vendra_app.dart';

void main() {
  testWidgets('menampilkan identitas aplikasi', (tester) async {
    await tester.pumpWidget(const TagihanVendraApp());

    expect(find.text('Tagihan Vendra'), findsOneWidget);
    expect(find.text('Aplikasi monitoring tagihan pribadi.'), findsOneWidget);
  });
}
