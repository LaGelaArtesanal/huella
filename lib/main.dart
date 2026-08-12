import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
// import 'package:firebase_app_check/firebase_app_check.dart'; // <--- COMENTADO TEMPORALMENTE
// import 'package:flutter/foundation.dart'; // <--- COMENTADO TEMPORALMENTE

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ️ DESACTIVADO TEMPORALMENTE PARA PRUEBAS EN EMULADOR
  // await FirebaseAppCheck.instance.activate(
  //   androidProvider: kReleaseMode
  //       ? AndroidProvider.playIntegrity
  //       : AndroidProvider.debug,
  // );

  await Firebase.initializeApp();
  runApp(const HuellaApp());
}

class HuellaApp extends StatelessWidget {
  const HuellaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Huella',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const LoginScreen(),
    );
  }
}