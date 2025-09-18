import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/rooms_screen.dart';
import 'services/matrix_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MatrixApp());
}

class MatrixApp extends StatelessWidget {
  const MatrixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MatrixService()..initialize(),
      child: MaterialApp(
        title: 'Matrix Chat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
          useMaterial3: true,
        ),
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const MatrixHome(),
      ),
    );
  }
}

class MatrixHome extends StatelessWidget {
  const MatrixHome({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<MatrixService>();
    if (service.isInitializing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!service.isLoggedIn) {
      return const LoginScreen();
    }

    return const RoomsScreen();
  }
}
