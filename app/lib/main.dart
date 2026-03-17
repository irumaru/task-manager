import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // google_sign_in の初期化は不要
  // ブラウザ OAuth はサインイン時にオンデマンドで動作する

  runApp(const ProviderScope(child: App()));
}
