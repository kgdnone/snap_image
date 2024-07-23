import 'package:flutter/material.dart';

final theme = ThemeData(
    appBarTheme: const AppBarTheme(toolbarHeight: 0),
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Colors.pinkAccent,
        onPrimary: Colors.white10,
        secondary: Colors.blue,
        onSecondary: Colors.black,
        error: Colors.deepOrange,
        onError: Colors.white10,
        background: Colors.white,
        onBackground: Colors.black38,
        surface: Colors.white10,
        onSurface: Colors.black38));
