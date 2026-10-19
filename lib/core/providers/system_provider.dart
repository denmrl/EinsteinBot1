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
    // Слушаем прямые сообщения из фонового изолята
    FlutterForegroundTask.addTaskDataCallback((data) {
      debugPrint('📩 [SystemProvider] Получено из фона: $data');
      if (data is Map && data['action'] != null) {
        _liveAction = data['action'].toString();
        notifyListeners();
      }
    });

    // На всякий случай опрашиваем Hive (вдруг сообщение из фона потерялось)
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _pollHive());
  }

  void _pollHive() {
    try {
      if (Hive.isBoxOpen('system_metrics')) {
        final box = Hive.box('system_metrics');
        final action = box.get('current_action', defaultValue: 'Ожидание...');
        if (action != _liveAction) {
          _liveAction = action.toString();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('⚠ [SystemProvider] Ошибка чтения Hive: $e');
    }
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
