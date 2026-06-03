import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'theme/bock_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authProvider = AuthProvider();
  await authProvider.restoreSession();
  runApp(
    ChangeNotifierProvider.value(value: authProvider, child: const BockStore()),
  );
}

class BockStore extends StatelessWidget {
  const BockStore({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bock Store',
      theme: BockTheme.light,
      darkTheme: BockTheme.dark,
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}
