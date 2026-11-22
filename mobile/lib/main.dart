import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/i18n.dart';
import 'core/theme.dart';
import 'state/cart.dart';
import 'ui/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
  final i18n = I18n();
  await i18n.load();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: i18n),
      ChangeNotifierProvider(create: (_) => Cart()),
    ],
    child: const FoodivoApp(),
  ));
}

class FoodivoApp extends StatelessWidget {
  const FoodivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<I18n>().locale;
    return MaterialApp(
      title: 'Foodivo',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: Locale(locale),
      home: const AuthGate(),
    );
  }
}
