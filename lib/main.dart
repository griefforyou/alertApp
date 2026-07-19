import 'package:flutter/material.dart';
import 'pages/timer_page.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudyTimerApp());
}

class StudyTimerApp extends StatefulWidget {
  const StudyTimerApp({super.key});

  @override
  State<StudyTimerApp> createState() => _StudyTimerAppState();
}

class _StudyTimerAppState extends State<StudyTimerApp> {
  ThemeMode _themeMode = ThemeMode.system;
  late final StorageService _storageService;

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final mode = await _storageService.loadThemeMode();
    if (mounted) {
      setState(() {
        _themeMode = _parseThemeMode(mode);
      });
    }
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _storageService.saveThemeMode(mode.name);
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '学习计时器',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      home: TimerPage(onThemeModeChanged: _setThemeMode, themeMode: _themeMode),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      colorSchemeSeed: const Color(0xFF2196F3),
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF0F7F4),
      textTheme: TextTheme(
        displayLarge: const TextStyle(fontSize: 57, fontWeight: FontWeight.w300),
        headlineMedium: const TextStyle(fontSize: 32, fontWeight: FontWeight.w500),
        titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        labelSmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ).apply(
        bodyColor: isDark ? Colors.white : Colors.black87,
        displayColor: isDark ? Colors.white : Colors.black87,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF8F8F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE0E0E0),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA),
      ),
    );
  }
}
