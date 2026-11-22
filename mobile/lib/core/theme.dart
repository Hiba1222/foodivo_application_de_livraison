import 'package:material_ui/material_ui.dart';

/// Foodivo palette — same values as web/tailwind.config.js (brand) + Tailwind slate/rose/amber.
class C {
  static const brand50 = Color(0xFFFFF7ED);
  static const brand100 = Color(0xFFFFEDD5);
  static const brand200 = Color(0xFFFED7AA);
  static const brand300 = Color(0xFFFDBA74);
  static const brand400 = Color(0xFFFB923C);
  static const brand500 = Color(0xFFF97316);
  static const brand600 = Color(0xFFEA580C);
  static const brand700 = Color(0xFFC2410C);

  static const rose50 = Color(0xFFFFF1F2);
  static const rose100 = Color(0xFFFFE4E6);
  static const rose300 = Color(0xFFFDA4AF);
  static const rose500 = Color(0xFFF43F5E);
  static const rose600 = Color(0xFFE11D48);
  static const red600 = Color(0xFFDC2626);
  static const amber100 = Color(0xFFFEF3C7);
  static const amber400 = Color(0xFFFBBF24);
  static const amber500 = Color(0xFFF59E0B);
  static const amber800 = Color(0xFF92400E);
  static const amber950 = Color(0xFF451A03);
  static const green100 = Color(0xFFDCFCE7);
  static const green500 = Color(0xFF22C55E);
  static const green600 = Color(0xFF16A34A);
  static const green700 = Color(0xFF15803D);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue700 = Color(0xFF1D4ED8);
  static const indigo100 = Color(0xFFE0E7FF);
  static const indigo700 = Color(0xFF4338CA);
  static const purple100 = Color(0xFFF3E8FF);
  static const purple700 = Color(0xFF7E22CE);

  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);

  static const brandGradient = LinearGradient(
    colors: [brand500, brand600, rose500],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const dealGradient = LinearGradient(colors: [rose600, Color(0xFFEF4444), amber500]);
  static const buttonGradient = LinearGradient(colors: [brand500, brand600]);
}

/// Shadows matching the web's `shadow-soft`, `shadow-lift`, `shadow-glow`.
class Shadows {
  static const soft = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x140F172A), blurRadius: 16, spreadRadius: -4, offset: Offset(0, 4)),
  ];
  static const lift = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x2E0F172A), blurRadius: 32, spreadRadius: -8, offset: Offset(0, 16)),
  ];
  static const glow = [
    BoxShadow(color: Color(0x8CEA580C), blurRadius: 24, spreadRadius: -6, offset: Offset(0, 8)),
  ];
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: C.brand600, primary: C.brand600, surface: Colors.white),
    scaffoldBackgroundColor: C.slate50,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: C.slate900,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(color: C.slate900, fontSize: 18, fontWeight: FontWeight.w800),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.slate300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.slate300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.brand500, width: 2)),
      labelStyle: const TextStyle(color: C.slate500),
      hintStyle: const TextStyle(color: C.slate400),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.slate900,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ),
    dividerTheme: const DividerThemeData(color: C.slate100, space: 1),
  );
}
