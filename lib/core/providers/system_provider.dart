import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/system_status.dart';
import '../../data/repositories/system_repository.dart';

class SystemProvider extends ChangeNotifier {
  Timer? _timer;
  String _liveAction = 'Ожидание...';

  SystemProvider() {
    // 1. Прямые сообщения из фона (работают мгновенно)
    FlutterForegroundTask.addTaskDataCallback((data) {
      if (data is Map && data['action'] != null) {
        _liveAction = data['action'].toString();
        notifyListeners();
      }
    });

    // 2. Опрос SharedPreferences раз в секунду (железобетонный способ)
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _pollSharedPrefs());
  }

  Future<void> _pollSharedPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Принудительно читаем с диска
      final action = prefs.getString('live_action') ?? 'Ожидание...';
      if (action != _liveAction) {
        _liveAction = action;
        notifyListeners();
      }
    } catch (_) {}
  }

  String get currentAction => _liveAction;
  List<String> get history => SystemRepository.instance.getHistory();
  Map<String, ApiMetric> get metrics => SystemRepository.instance.getAllMetrics();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
