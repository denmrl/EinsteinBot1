import 'package:hive_ce_flutter/hive_flutter.dart';
import '../models/system_status.dart';

class SystemRepository {
  SystemRepository._internal();
  static final SystemRepository instance = SystemRepository._internal();

  Box get _box => Hive.box('system_metrics');

  Future<void> updateAction(String action) async {
    await _box.put('current_action', action);
    await _box.put('last_action_time', DateTime.now().millisecondsSinceEpoch);
    
    // Сохраняем последние 20 действий для истории
    List<dynamic> history = _box.get('history', defaultValue: []);
    history.add('${DateTime.now().toString().substring(11, 19)} - $action');
    if (history.length > 20) history.removeAt(0);
    await _box.put('history', history);
  }

  Future<void> logApiCall(String apiName, bool isSuccess, int latencyMs, {String? errorMsg}) async {
    final key = 'api_$apiName';
    final raw = _box.get(key);
    ApiMetric metric = raw != null ? ApiMetric.fromMap(raw) : ApiMetric(name: apiName, lastUpdate: DateTime.now());

    metric = ApiMetric(
      name: apiName,
      successCount: metric.successCount + (isSuccess ? 1 : 0),
      errorCount: metric.errorCount + (isSuccess ? 0 : 1),
      lastLatencyMs: latencyMs,
      lastError: errorMsg,
      lastUpdate: DateTime.now(),
    );
    
    await _box.put(key, metric.toMap());
  }

  Map<String, ApiMetric> getAllMetrics() {
    final result = <String, ApiMetric>{};
    for (final key in _box.keys) {
      if (key.toString().startsWith('api_')) {
        result[key.toString().replaceAll('api_', '')] = ApiMetric.fromMap(_box.get(key));
      }
    }
    return result;
  }

  String getCurrentAction() => _box.get('current_action', defaultValue: 'Ожидание...');
  List<String> getHistory() => List<String>.from(_box.get('history', defaultValue: []));
}
