import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
    useMaterial3: true,
    brightness: Brightness.light,
  );
}
