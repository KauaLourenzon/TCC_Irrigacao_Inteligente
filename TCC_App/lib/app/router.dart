import 'package:go_router/go_router.dart';

import 'app.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, _) => const PlaceholderScreen(title: 'Login'),
    ),
    GoRoute(
      path: '/cadastro',
      builder: (_, _) => const PlaceholderScreen(title: 'Cadastro'),
    ),
    GoRoute(
      path: '/recuperar-senha',
      builder: (_, _) => const PlaceholderScreen(title: 'Recuperar senha'),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (_, _) =>
          const PlaceholderScreen(title: 'Configuração do dispositivo'),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (_, _) => const PlaceholderScreen(title: 'Dashboard'),
    ),
    GoRoute(
      path: '/dispositivos',
      builder: (_, _) => const PlaceholderScreen(title: 'Dispositivos ESP32'),
    ),
    GoRoute(
      path: '/plantas',
      builder: (_, _) => const PlaceholderScreen(title: 'Plantas e perfis'),
    ),
    GoRoute(
      path: '/irrigacao',
      builder: (_, _) =>
          const PlaceholderScreen(title: 'Controle de irrigação'),
    ),
    GoRoute(
      path: '/historico',
      builder: (_, _) => const PlaceholderScreen(title: 'Histórico e gráficos'),
    ),
    GoRoute(
      path: '/configuracoes',
      builder: (_, _) => const PlaceholderScreen(title: 'Configurações'),
    ),
  ],
);
