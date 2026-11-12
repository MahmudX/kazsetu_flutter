import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazsetu_mobile/ui.dart';

void main() {
  Future<void> render(WidgetTester tester, String md) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: UserMarkdown(md))),
      );

  testWidgets('renders basic markdown without the markup symbols', (tester) async {
    await render(tester, '**bold** text\n\n- one\n- two');
    expect(find.textContaining('bold text', findRichText: true), findsOneWidget);
    expect(find.textContaining('**', findRichText: true), findsNothing);
    expect(find.textContaining('one', findRichText: true), findsOneWidget);
  });

  testWidgets('never loads a remote image, shows its alt text instead', (tester) async {
    await render(tester, '![cat photo](https://evil.example/pixel.png)');
    expect(find.byType(Image), findsNothing);
    expect(find.text('cat photo'), findsOneWidget);
  });

  testWidgets('raw HTML is not interpreted', (tester) async {
    await render(tester, 'hi <img src="https://evil.example/x.png"> there');
    expect(find.byType(Image), findsNothing);
  });
}
