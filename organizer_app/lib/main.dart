import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/wedding_selection_screen.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize local Supabase connection
  await SupabaseService.instance.initialize();

  runApp(const MyApp());
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
          headlineLarge: TextStyle(fontFamily: 'Outfit', fontSize: 32, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold),
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

class RootNavigator extends StatelessWidget {
  const RootNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = SupabaseService.instance;

    if (!supabase.isAuthenticated) {
      return const AuthScreen();
    }

    if (supabase.getSelectedWeddingId() == null) {
      return const WeddingSelectionScreen();
    }

    return const HomeScreen();
  }
}
