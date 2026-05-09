import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/api/websocket_client.dart';
import 'auth_provider.dart';
import 'status_provider.dart';
import 'tag_provider.dart';
import 'task_provider.dart';
import 'wish_label_provider.dart';
import 'wish_provider.dart';

final websocketProvider = Provider<WebSocketClient?>((ref) {
  final authState = ref.watch(authNotifierProvider).value;
  if (authState?.status != AuthStatus.authenticated) return null;

  final client = WebSocketClient();
  client.connect(AppConstants.apiBaseUrl, authState!.accessToken!);

  client.events.listen((event) {
    switch (event.type) {
      case 'task.changed':
        ref.invalidate(tasksProvider);
      case 'status.changed':
        ref.invalidate(statusNotifierProvider);
      case 'tag.changed':
        ref.invalidate(tagNotifierProvider);
      case 'wish.changed':
        ref.invalidate(wishesProvider);
      case 'wish_label.changed':
        ref.invalidate(wishLabelNotifierProvider);
    }
  });

  ref.onDispose(client.dispose);
  return client;
});
