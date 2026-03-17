import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 72),
              const SizedBox(height: 24),
              Text(
                'タスクマネージャー',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 48),
              if (authAsync.isLoading)
                const CircularProgressIndicator()
              else ...[
                if (authAsync.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'サインインに失敗しました',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                FilledButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Google でサインイン'),
                  onPressed: () => ref
                      .read(authNotifierProvider.notifier)
                      .signInWithGoogle(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
