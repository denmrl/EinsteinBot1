import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    backgroundColor: Color(0xFF0000FF), // ЧИСТЫЙ СИНИЙ
    body: Center(
      child: Text(
        'ЭТАП 5: СИНИЙ ФОН',
        style: TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ),
));
