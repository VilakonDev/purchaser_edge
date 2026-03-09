import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import 'package:purchaser_edge/providers/auth_provider.dart';
import 'package:purchaser_edge/providers/document_provider.dart';
import 'package:purchaser_edge/providers/file_provider.dart';
import 'package:purchaser_edge/providers/user_provider.dart';
import 'package:purchaser_edge/screens/login_screen.dart';
import 'package:purchaser_edge/screens/sign_license_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FileProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: 'Purchaser Edge',
        debugShowCheckedModeBanner: false,
        home: const AuthPage(),
        theme: ThemeData(textTheme: GoogleFonts.notoSansLaoTextTheme()),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checked) {
      _checked = true;
      _checkLicense();
    }
  }

  Future<void> _checkLicense() async {
    try {
      final isValid = await context.read<AuthProvider>().verifyLicense();
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              isValid ? const LoginScreen() : const SignLicenseScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SignLicenseScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}