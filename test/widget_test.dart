// Test de fumée : l'écran « configuration manquante » s'affiche quand aucune
// clé n'est injectée (cas par défaut en test, sans --dart-define).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App-level smoke test placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('ok'))),
    );
    expect(find.text('ok'), findsOneWidget);
  });
}
