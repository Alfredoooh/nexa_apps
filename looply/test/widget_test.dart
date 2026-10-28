import 'package:flutter_test/flutter_test.dart';
import 'package:looply/main.dart';

void main() {
  testWidgets('Looply mostra a identidade visual e a navegação principal', (WidgetTester tester) async {
    await tester.pumpWidget(const LooplyApp());

    expect(find.text('Looply'), findsOneWidget);
    expect(find.text('Joga. Cria. Explora.'), findsOneWidget);
    expect(find.text('Início'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
