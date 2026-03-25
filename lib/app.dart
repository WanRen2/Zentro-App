import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/profile_screen.dart';
import 'screens/home_screen.dart';
import 'managers/profile_manager.dart';

class ZentroApp extends StatefulWidget {
  const ZentroApp({super.key});

  @override
  State<ZentroApp> createState() => _ZentroAppState();
}

class _ZentroAppState extends State<ZentroApp> {
  bool _isLoading = true;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final pm = ProfileManager();
    final profile = await pm.loadProfile();
    setState(() {
      _hasProfile = profile != null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zentro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _isLoading
          ? const Scaffold(
              backgroundColor: Color(0xFF0A0A0A),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF00FF9C)),
              ),
            )
          : _hasProfile
          ? const HomeScreen()
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
