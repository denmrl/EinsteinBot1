import 'package:flutter/foundation.dart';

class ApiMetric {
  final String name;
  final int successCount;
  final int errorCount;
  final int lastLatencyMs;
  final DateTime lastUpdate;

  const ApiMetric({
    required this.name,
    this.successCount = 0,
    this.errorCount = 0,
    this.lastLatencyMs = 0,
    required this.lastUpdate,
  });

  Map<String, dynamic> toMap() => {
    'name': name, 'successCount': successCount, 'errorCount': errorCount,
    'lastLatencyMs': lastLatencyMs, 'lastUpdate': lastUpdate.millisecondsSinceEpoch,
  };

  factory ApiMetric.fromMap(Map<dynamic, dynamic> map) => ApiMetric(
    name: map['name'] ?? '',
    successCount: map['successCount'] ?? 0,
    errorCount: map['errorCount'] ?? 0,
    lastLatencyMs: map['lastLatencyMs'] ?? 0,
    lastUpdate: DateTime.fromMillisecondsSinceEpoch(map['lastUpdate'] ?? 0),
  );
}
