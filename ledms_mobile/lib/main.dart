import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'login_screen.dart';
import 'screens/docs_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final token = await const FlutterSecureStorage().read(key: 'access_token');

  runApp(
    MaterialApp(
      title: 'LEDMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2563EB),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: token != null ? const DocsListScreen() : LoginScreen(),
    ),
  );
}
