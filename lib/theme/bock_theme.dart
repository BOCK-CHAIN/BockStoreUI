import 'package:flutter/material.dart';
import 'bock_colors.dart';

class BockTheme {
  BockTheme._();

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BockColors.purple,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: BockColors.bgDark,
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BockColors.purple,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: BockColors.bgLight,
  );
}
