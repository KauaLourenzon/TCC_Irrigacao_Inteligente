import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _authGreen = Color(0xFF00513E);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  bool isSignUp = false;
  bool isBusy = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.length < 6) {
      showMessage('Informe um e-mail e uma senha com pelo menos 6 caracteres.');
      return;
    }
    setState(() => isBusy = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (isSignUp) {
        final response = await auth.signUp(
          email: email,
          password: password,
          data: {'display_name': nameController.text.trim()},
        );
        if (!mounted) return;
        if (response.session == null) {
          showMessage('Cadastro realizado. Verifique seu e-mail para entrar.');
        }
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (error) {
      showMessage(error.message);
    } catch (_) {
      showMessage('Não foi possível conectar ao Supabase.');
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7FAF5),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.local_florist, color: _authGreen, size: 64),
                const SizedBox(height: 14),
                Text(
                  isSignUp ? 'Criar conta' : 'Entrar',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _authGreen,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isSignUp
                      ? 'Crie sua conta para salvar as plantas no Supabase.'
                      : 'Entre para acessar suas plantas e configurações.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 28),
                if (isSignUp) ...[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isBusy ? null : submit,
                  child: Text(isBusy
                      ? 'Aguarde...'
                      : (isSignUp ? 'Cadastrar' : 'Entrar')),
                ),
                TextButton(
                  onPressed: isBusy ? null : () => setState(() => isSignUp = !isSignUp),
                  child: Text(isSignUp
                      ? 'Já tenho uma conta'
                      : 'Ainda não tenho uma conta'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
