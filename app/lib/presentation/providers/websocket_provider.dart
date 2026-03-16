import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/api/websocket_client.dart';
import 'auth_provider.dart';
import 'priority_provider.dart';
import 'status_provider.dart';
import 'tag_provider.dart';
import 'task_provider.dart';

final websocketProvider = Provider<WebSocketClient?>((ref) {
  final authState = ref.watch(authNotifierProvider).value;
  if (authState?.status != AuthStatus.authenticated) return null;

  final client = WebSocketClient();
  client.connect(AppConstants.apiBaseUrl, authState!.accessToken!);

  client.events.listen((event) {
    switch (event.type) {
      case 'task.created' || 'task.updated' || 'task.deleted':
        ref.invalidate(tasksProvider);
      case 'priority.created' || 'priority.updated' || 'priority.deleted':
        ref.invalidate(priorityNotifierProvider);
      case 'status.created' || 'status.updated' || 'status.deleted':
        ref.invalidate(statusNotifierProvider);
      case 'tag.created' || 'tag.updated' || 'tag.deleted':
        ref.invalidate(tagNotifierProvider);
    }
  });

  ref.onDispose(client.dispose);
  return client;
});
