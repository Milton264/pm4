import 'package:flutter/material.dart';
import 'ui/access.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ValhallaApp());
}

const ink = Color(0xFF20221F),
    gold = Color(0xFFD9B86F),
    forest = Color(0xFF33654E),
    paper = Color(0xFFF5F3ED);

class ValhallaApp extends StatelessWidget {
  final Widget? home;
  const ValhallaApp({super.key, this.home});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Valhalla · Gestión',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'ValhallaSans',
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: forest,
        primary: forest,
        secondary: gold,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        centerTitle: false,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDFE2D9)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFDFE2D9)),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.2,
          color: ink,
        ),
        headlineSmall: TextStyle(fontWeight: FontWeight.w600, color: ink),
      ),
    ),
    home: home ?? const AccessGate(),
  );
}
