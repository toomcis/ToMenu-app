import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';           // ← ADD
import 'package:firebase_messaging/firebase_messaging.dart'; // ← ADD
import 'firebase_options.dart';                              // ← ADD
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'screens/main_shell.dart';
import 'l10n/strings.dart';
import 'services/auth_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {}  // ← ADD

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // ← ADD
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);              // ← ADD
  await FirebaseMessaging.instance.requestPermission();                           // ← ADD
  await AuthService.instance.init();
  // ... rest is unchanged
  await NotificationService.instance.init();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // load saved preferences
  final prefs = await SharedPreferences.getInstance();
  final savedThemeMode = prefs.getString('theme_mode') ?? 'system';
  final savedAccent = prefs.getInt('accent_color') ?? 0xFF4ADE80; // default green
  // L10n init happens inside app after context is available
  runApp(ToMenuApp(
    initialThemeMode: _parseThemeMode(savedThemeMode),
    initialAccentColor: Color(savedAccent),
  ));
}

ThemeMode _parseThemeMode(String value) {
  switch (value) {
    case 'dark':   return ThemeMode.dark;
    case 'light':  return ThemeMode.light;
    default:       return ThemeMode.system;
  }
}

// The root widget. Holds theme state so any screen can trigger a theme change.
class ToMenuApp extends StatefulWidget {
  final ThemeMode initialThemeMode;
  final Color initialAccentColor;

  const ToMenuApp({
    super.key,
    required this.initialThemeMode,
    required this.initialAccentColor,
  });

  // static method so any widget can call ToMenuApp.of(context).setTheme(...)
  static _ToMenuAppState of(BuildContext context) {
    return context.findAncestorStateOfType<_ToMenuAppState>()!;
  }

  @override
  State<ToMenuApp> createState() => _ToMenuAppState();
}

class _ToMenuAppState extends State<ToMenuApp> {
  late ThemeMode _themeMode;
  late Color _accentColor;

  @override
  void initState() {
    super.initState();
    _themeMode   = widget.initialThemeMode;
    _accentColor = widget.initialAccentColor;
  }

  // call this from settings screen to switch theme
  void setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    final modeStr = mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system';
    await prefs.setString('theme_mode', modeStr);
  }

  // call this from settings screen to change language
  void setLanguage(AppLanguage language) async {
    await L10n.setLanguage(language, context);
    setState(() {}); // rebuild entire tree with new strings
  }

  // call this from settings screen to change accent color
  void setAccentColor(Color color) async {
    setState(() => _accentColor = color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent_color', color.toARGB32());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToMenu',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme:      AppTheme.light(_accentColor),
      darkTheme:  AppTheme.dark(_accentColor),
      home: FutureBuilder(
        future: L10n.init(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(); // splash/loading
          }
          return const MainShell();
        },
      ),
    );
  }
}