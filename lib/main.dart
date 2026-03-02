import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchaser_edge/screens/home_screen.dart';
import 'package:purchaser_edge/screens/login_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Purchaser Edge',
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
      theme: ThemeData(textTheme: GoogleFonts.notoSansLaoTextTheme()),
    );
  }
}
