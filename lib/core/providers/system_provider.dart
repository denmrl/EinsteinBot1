import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../../data/models/system_status.dart';
import '../../data/repositories/system_repository.dart';

class SystemProvider extends ChangeNotifier {
  Timer? _timer;
  String _liveAction = 'Ожидание...';

  SystemProvider() {
    // 1. Слушаем прямые сообщения из фонового изолята
    FlutterForegroundTask.addTaskDataCallback((data) {
      if (data is Map && data['action'] != null) {
        _liveAction = data['action'].toString();
        notifyListeners();
      }
    });

    // 2. Каждые 2 секунды принудительно перечитываем Hive (для графиков и логов)
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _pollHive());
  }

  void _pollHive() async {
    try {
      final box = Hive.box('system_metrics');
      await box.reload(); // Принудительно читаем с диска
      
      final action = box.get('current_action', defaultValue: 'Ожидание...');
      if (action != _liveAction) {
        _liveAction = action;
      }
      notifyListeners();
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
