import 'package:flutter/material.dart';

import 'foundation/app_config.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/wedding_selection_screen.dart';
import 'services/session_recovery.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseService.instance.initialize();
    runApp(const MyApp());
  } on AppConfigException catch (error) {
    runApp(ConfigurationErrorApp(message: error.message));
  }
}

class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeddingOS Organizer Workspace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6B4EFF),
        scaffoldBackgroundColor: const Color(0xFF0F0C1B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6B4EFF),
          secondary: Color(0xFFFF5E7E),
          surface: Color(0xFF16122C),
          onSurface: Colors.white,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          titleMedium: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 15),
          bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 13),
        ),
      ),
      // Determine the initial route dynamically
      home: const RootNavigator(),
      routes: {
        '/auth': (_) => const AuthScreen(),
        '/wedding-selection': (_) => const WeddingSelectionScreen(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}

class RootNavigator extends StatefulWidget {
  const RootNavigator({super.key});

  @override
  State<RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<RootNavigator>
    with WidgetsBindingObserver {
  late Future<WeddingAccessResolution> _access;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SupabaseService.instance.sessionRecovery.addListener(_sessionChanged);
    _access = _resolveAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SupabaseService.instance.sessionRecovery.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _access = _resolveAccess());
    }
  }

  void _sessionChanged() {
    if (!mounted) return;
    setState(() => _access = _resolveAccess());
  }

  Future<WeddingAccessResolution> _resolveAccess() async {
    final supabase = SupabaseService.instance;
    if (supabase.sessionRecovery.status != AppSessionStatus.authenticated) {
      return const WeddingAccessResolution(WeddingAccessDestination.selection);
    }
    try {
      return await supabase.revalidateSelectedWedding();
    } catch (error) {
      await supabase.handleOperationalError(error);
      return const WeddingAccessResolution(WeddingAccessDestination.selection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = SupabaseService.instance;

    if (supabase.sessionRecovery.status != AppSessionStatus.authenticated) {
      return const AuthScreen();
    }

    return FutureBuilder<WeddingAccessResolution>(
      future: _access,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (supabase.sessionRecovery.status != AppSessionStatus.authenticated) {
          return const AuthScreen();
        }
        return snapshot.data?.destination == WeddingAccessDestination.home
            ? const HomeScreen()
            : const WeddingSelectionScreen();
      },
    );
  }
}
