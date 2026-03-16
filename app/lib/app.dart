import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'presentation/pages/login/login_page.dart';
import 'presentation/pages/settings/settings_page.dart';
import 'presentation/pages/task_list/task_list_page.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/websocket_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);

    // ログイン済みの場合は WebSocket 接続を確立
    if (authAsync.value?.status == AuthStatus.authenticated) {
      ref.watch(websocketProvider);
    }

    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: authAsync.when(
        data: (state) => switch (state.status) {
          AuthStatus.authenticated => const MainShell(),
          AuthStatus.unauthenticated => const LoginPage(),
          AuthStatus.unknown => const _Splash(),
        },
        loading: () => const _Splash(),
        error: (_, __) => const LoginPage(),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _pages = const [
    TaskListPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'タスク'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: '設定'),
        ],
      ),
    );
  }
}
