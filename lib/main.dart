import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:purchaser_edge/providers/file_provider.dart';
import 'package:purchaser_edge/screens/login_screen.dart';
import 'package:purchaser_edge/screens/sign_license_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FileProvider())
      ],
      child: MaterialApp(
        title: 'Purchaser Edge',
        debugShowCheckedModeBanner: false,
        home: SignLicenseScreen(),
        theme: ThemeData(textTheme: GoogleFonts.notoSansLaoTextTheme()),
      ),
    );
  }
}
