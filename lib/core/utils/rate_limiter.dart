import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class RateLimiter {
  RateLimiter._internal();
  static final RateLimiter instance = RateLimiter._internal();

  static const int _delayMs = 2000;
  Future<void> _tail = Future.value();

  Future<void> wait() {
    final completer = Completer<void>();
    _tail = _tail.then((_) async {
      try {
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
      } catch (_) {
        await Future.delayed(Duration(milliseconds: _delayMs));
      }
      completer.complete();
    });
    return completer.future;
  }
}
