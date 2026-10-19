import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/system_status.dart';

class SystemRepository {
  SystemRepository._internal();
  static final SystemRepository instance = SystemRepository._internal();

  Box get _box => Hive.box('system_metrics');

  Future<void> updateAction(String action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('live_action', action);
    
    // Сохраняем последние 20 действий для истории в SharedPreferences
    List<String> history = prefs.getStringList('action_history') ?? [];
    
    final timeStr = DateTime.now().toString().substring(11, 19);
    final logEntry = '[$timeStr] $action';
    
    history.add(logEntry);
    if (history.length > 50) history.removeAt(0);
    await prefs.setStringList('action_history', history);
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
      lastUpdate: DateTime.now(),
      lastError: errorMsg,
    );
    
    await _box.put(key, metric.toMap());
    
    if (!isSuccess && errorMsg != null) {
      await updateAction('[ERR] $apiName: $errorMsg');
    }
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
  List<String> getHistory() => [];
}
