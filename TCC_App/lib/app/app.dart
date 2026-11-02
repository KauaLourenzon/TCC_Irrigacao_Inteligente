import 'package:flutter/material.dart';

import 'theme.dart';
import '../features/mock_ui/mock_app.dart';

class IrrigacaoInteligenteApp extends StatelessWidget {
  const IrrigacaoInteligenteApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Irrigação Inteligente',
    theme: AppTheme.light,
    home: const MockAppShell(),
    debugShowCheckedModeBanner: false,
  );
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.title, super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Text(
        '$title\nMódulo preparado para implementação.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}
