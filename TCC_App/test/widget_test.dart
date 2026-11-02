import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:irrigacao_inteligente/app/app.dart';

void main() {
  testWidgets('aplicativo inicia corretamente', (tester) async {
    await tester.pumpWidget(const IrrigacaoInteligenteApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
