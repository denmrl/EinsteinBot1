import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/system_status.dart';
import '../../data/repositories/system_repository.dart';

class SystemProvider extends ChangeNotifier {
  Timer? _timer;
  String _liveAction = 'Ожидание...';
  List<String> _history = [];

  SystemProvider() {
    FlutterForegroundTask.addTaskDataCallback((data) {
      if (data is Map && data['action'] != null) {
        _liveAction = data['action'].toString();
        notifyListeners();
      }
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _pollSharedPrefs());
  }

  Future<void> _pollSharedPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      
      final action = prefs.getString('live_action') ?? 'Ожидание...';
      final hist = prefs.getStringList('action_history') ?? [];
      
      bool changed = false;
      if (action != _liveAction) { _liveAction = action; changed = true; }
      if (hist.length != _history.length || (hist.isNotEmpty && _history.isNotEmpty && hist.last != _history.last)) {
        _history = hist; changed = true;
      }
      
      if (changed) notifyListeners();
    } catch (_) {}
  }

  String get currentAction => _liveAction;
  List<String> get history => _history;
  Map<String, ApiMetric> get metrics => SystemRepository.instance.getAllMetrics();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
