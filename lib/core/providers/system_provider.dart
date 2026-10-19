import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../../data/models/system_status.dart';
import '../../data/repositories/system_repository.dart';

class SystemProvider extends ChangeNotifier {
  SystemProvider() {
    _attachListener();
  }

  void _attachListener() {
    Hive.box('system_metrics').listenable().addListener(_reload);
  }

  void _reload() {
    notifyListeners();
  }

  String get currentAction => SystemRepository.instance.getCurrentAction();
  List<String> get history => SystemRepository.instance.getHistory();
  Map<String, ApiMetric> get metrics => SystemRepository.instance.getAllMetrics();

  @override
  void dispose() {
    Hive.box('system_metrics').listenable().removeListener(_reload);
    super.dispose();
  }
}
