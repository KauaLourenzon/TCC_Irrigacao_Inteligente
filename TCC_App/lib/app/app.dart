import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';
import '../core/config/environment.dart';
import '../features/auth/auth_screen.dart';
import '../features/mock_ui/mock_app.dart';

class IrrigacaoInteligenteApp extends StatelessWidget {
  const IrrigacaoInteligenteApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Irrigação Inteligente',
    theme: AppTheme.light,
    home: Environment.isSupabaseConfigured
        ? const SupabaseAuthGate()
        : const MockAppShell(),
    debugShowCheckedModeBanner: false,
  );
}

class SupabaseAuthGate extends StatelessWidget {
  const SupabaseAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;
        if (session == null) return const AuthScreen();
        return MockAppShell(
          useSupabase: true,
          key: ValueKey(session.user.id),
        );
      },
    );
  }
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
