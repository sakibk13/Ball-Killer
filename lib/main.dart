import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // REQUIRED IMPORT
import 'providers/auth_provider.dart';
import 'providers/ball_provider.dart';
import 'providers/contribution_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/fine_provider.dart';
import 'providers/fund_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with explicit options for better reliability
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BallProvider()),
        ChangeNotifierProvider(create: (_) => ContributionProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => FineProvider()),
        ChangeNotifierProvider(create: (_) => FundProvider()),
      ],
      child: const BallKillerApp(),
    ),
  );
}

class BallKillerApp extends StatelessWidget {
  const BallKillerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ball Killer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF051970),
          primary: const Color(0xFF051970),
          secondary: Colors.tealAccent,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: const Color(0xFF051970),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.currentUser != null) {
            return const DashboardScreen();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}