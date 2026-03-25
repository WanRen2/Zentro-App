import 'package:flutter/material.dart';
import 'theme/theme_manager.dart';
import 'screens/profile_screen.dart';
import 'screens/main_screen.dart';
import 'managers/profile_manager.dart';

class ZentroApp extends StatefulWidget {
  const ZentroApp({super.key});

  @override
  State<ZentroApp> createState() => _ZentroAppState();
}

class _ZentroAppState extends State<ZentroApp> {
  bool _isLoading = true;
  bool _hasProfile = false;
  final _themeManager = ThemeManager();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _themeManager.loadTheme();
    await _checkProfile();
  }

  Future<void> _checkProfile() async {
    final pm = ProfileManager();
    final profile = await pm.loadProfile();
    if (mounted) {
      setState(() {
        _hasProfile = profile != null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zentro',
      debugShowCheckedModeBanner: false,
      theme: _themeManager.getThemeData(),
      home: _isLoading
          ? Scaffold(
              backgroundColor: _themeManager.bg,
              body: Center(
                child: CircularProgressIndicator(color: _themeManager.accent),
              ),
            )
          : _hasProfile
          ? const MainScreen()
          : const ProfileScreen(),
    );
  }
}

// Compatibility shim for tests
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ProfileScreen());
  }
}
