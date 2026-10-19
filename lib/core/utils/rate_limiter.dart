import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class RateLimiter {
  RateLimiter._internal();
  static final RateLimiter instance = RateLimiter._internal();

  static const int _delayMs = 1650; // Чуть больше 1.6 для запаса
  Future<void> _tail = Future.value();

  Future<void> wait() {
    final completer = Completer<void>();
    _tail = _tail.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      
      final lastCallMs = prefs.getInt('global_last_api_call') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - lastCallMs;

      if (elapsed < _delayMs) {
        await Future.delayed(Duration(milliseconds: _delayMs - elapsed));
      }

      final newTime = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('global_last_api_call', newTime);
      
      completer.complete();
    });
    return completer.future;
  }
}
