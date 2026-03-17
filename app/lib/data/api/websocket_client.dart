import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketEvent {
  final String type;
  final Map<String, dynamic> data;

  WebSocketEvent({required this.type, required this.data});

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    return WebSocketEvent(
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>,
    );
  }
}

class WebSocketClient {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final _eventController = StreamController<WebSocketEvent>.broadcast();

  String? _baseUrl;
  String? _token;

  Stream<WebSocketEvent> get events => _eventController.stream;

  Future<void> connect(String baseUrl, String token) async {
    _baseUrl = baseUrl;
    _token = token;
    _reconnectAttempts = 0;
    _connect();
  }

  void _connect() {
    if (_baseUrl == null || _token == null) return;

    final wsUrl = _baseUrl!.replaceFirst(RegExp(r'^http'), 'ws');
    _channel = WebSocketChannel.connect(
      Uri.parse('$wsUrl/ws?token=$_token'),
    );

    _channel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          _eventController.add(WebSocketEvent.fromJson(json));
        } catch (_) {
          // 不正な JSON は無視
        }
      },
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
    );
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    // 指数バックオフ: 1s → 2s → 4s → ... → 最大 30s
    final delay = min(30, pow(2, _reconnectAttempts).toInt());
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: delay), _connect);
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _eventController.close();
  }
}
