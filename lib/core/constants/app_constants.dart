// ==========================================================
//  ЭЙНШТЕЙН — Глобальные константы приложения
//  Файл: lib/core/constants/app_constants.dart
//  Все значения перенесены из старого Python-скрипта 1:1.
// ==========================================================

/// Единый класс со всеми торговыми и системными константами.
/// Использовать так: AppConstants.MIN_TURNOVER_24H
class AppConstants {
  // Приватный конструктор — класс только для статики, экземпляр не нужен.
  AppConstants._();

  // ==========================================================
  // 🏷 ИМЯ ПРИЛОЖЕНИЯ И ВЕРСИЯ
  // ==========================================================
  static const String APP_NAME = 'Эйнштейн';
  static const String APP_VERSION = '1.0.0';

  // ==========================================================
  // 🎯 ФИЛЬТРЫ ЛИКВИДНОСТИ И КАПЫ (перенос из Python)
  // ==========================================================

  /// Минимальный оборот за 24ч в USDT ($300k)
  static const double MIN_TURNOVER_24H = 300000.0;

  /// Максимальный оборот за 24ч в USDT ($40M)
  /// Монеты с большим оборотом — «слишком большие», нас не интересуют.
  static const double MAX_TURNOVER_24H = 40000000.0;

  /// Минимальный открытый интерес (Open Interest) в USDT ($100k)
  /// Монеты с меньшим OI — слишком «мёртвые» и манипулируемые.
  static const double MIN_OPEN_INTEREST = 100000.0;

  /// Коэффициент для оценочной капитализации: est_cap = turnover * 3.5
  static const double CAP_MULTIPLIER = 3.5;

  /// Минимальная оценочная капа ($1M)
  static const double MIN_ESTIMATED_CAP = 1000000.0;

  /// Максимальная оценочная капа ($150M)
  static const double MAX_ESTIMATED_CAP = 150000000.0;

  /// Список «слишком крупных» монет, которые исключаем из поиска.
  /// (Перенесён из Python EXCLUDE_SYMBOLS.)
  static const Set<String> EXCLUDE_SYMBOLS = {
    'BTCUSDT', 'ETHUSDT', 'SOLUSDT', 'XRPUSDT', 'BNBUSDT',
    'DOGEUSDT', 'ADAUSDT', 'AVAXUSDT', 'LINKUSDT', 'SUIUSDT',
  };

  // ==========================================================
  // 🛡 RATE LIMITER (Bybit Market Data: 120 запросов/мин)
  // ==========================================================

  /// Пауза между ВСЕМИ запросами к Bybit API (в секундах).
  /// 1.6 сек × 60 = 96 запросов/мин — гарантированно ниже лимита 120.
  static const double RATE_LIMIT_DELAY_SEC = 1.60;

  /// recv_window для подписи приватных запросов Bybit V5 (мс).
  /// 20000 мс = 20 секунд — защита от рассинхрона времени.
  static const int BYBIT_RECV_WINDOW = 20000;

  /// Таймаут HTTP-запроса к Bybit API (в секундах).
  static const int BYBIT_TIMEOUT_SEC = 20;

  /// Максимальное количество попыток при ошибках API.
  static const int API_MAX_RETRIES = 5;

  // ==========================================================
  // 📦 КЭШ СВЕЧЕЙ (TTL в секундах — сколько держать в памяти)
  // ==========================================================
  static const int KLINE_TTL_5M = 30;
  static const int KLINE_TTL_15M = 60;
  static const int KLINE_TTL_1H = 300;
  static const int KLINE_TTL_1D = 3600;

  /// Лимит свечей в одном запросе.
  static const int KLINE_LIMIT = 40;

  // ==========================================================
  // 🧮 ИНДИКАТОРЫ
  // ==========================================================
  static const int EMA_FAST = 9;
  static const int EMA_SLOW = 20;
  static const int RSI_PERIOD = 14;
  static const int ATR_PERIOD = 14;

  /// RSI не должен превышать это значение перед входом (защита от покупки «на хаях»).
  static const double RSI_MAX_ENTRY = 72.0;

  // ==========================================================
  // 🎯 МАКРО-ФИЛЬТР УКАЦА
  // ==========================================================

  /// Минимальный ATR% — если ниже, монета в «мёртвом флэте».
  static const double MIN_ATR_PCT = 0.25;

  /// Максимальное расстояние от исторического дна (в %).
  /// Если цена выше дна более чем на 38% — поздний вход, пропускаем.
  static const double MAX_PRICE_FROM_BOTTOM_PCT = 38.0;

  /// Минимальная глубина «уката» (дампа) от максимума недели (в %).
  /// Если монета упала меньше чем на 30% — это не наш сетап.
  static const double MIN_DUMP_DEPTH_PCT = 30.0;

  // ==========================================================
  // 👁 ПАРАМЕТРЫ ПАТТЕРНОВ (detect_chart_patterns)
  // ==========================================================

  /// Минимум свечей для анализа паттерна (15m или 5m).
  static const int PATTERN_MIN_CANDLES = 30;

  /// 1. Бычий Флаг / Канал: минимальный импульс роста перед консолидацией.
  static const double FLAG_MIN_IMPULSE = 0.08; // 8%

  /// 1. Бычий Флаг: сжатие диапазона консолидации (≤ 45% от общего).
  static const double FLAG_MAX_RECENT_RANGE = 0.45;

  /// 1. Бычий Флаг: цена должна быть в верхних 40% диапазона.
  static const double FLAG_MIN_PRICE_POSITION = 0.60;

  /// 2. Восходящий Треугольник: разница между low_1 / low_2 / low_3.
  static const double TRIANGLE_LOW_EPSILON = 1.015;

  /// 2. Треугольник: максимальное расстояние до хая (2%).
  static const double TRIANGLE_MAX_DIST_TO_HIGH = 0.02;

  /// 3. V-Разворот: нижняя тень ≥ тела свечи × коэффициент.
  static const double VREV_WICK_BODY_RATIO = 1.6;

  /// 3. V-Разворот: объём последней свечи ≥ среднего × коэффициент.
  static const double VREV_VOLUME_SPIKE = 1.8;

  /// 4. Накопление: цена должна быть в верхних 1.5% диапазона.
  static const double ACCUMULATION_NEAR_HIGH = 0.985;

  // ==========================================================
  // 🔍 ЛОГИКА НАБЛЮДЕНИЯ (watched → активная сделка)
  // ==========================================================

  /// Множитель триггера: last_price * 1.012 = цена пробоя.
  static const double TRIGGER_MULTIPLIER = 1.012;

  /// Объёмный спайк в 15m для подтверждения входа (× от среднего).
  static const double ENTRY_VOLUME_SPIKE = 1.8;

  // ==========================================================
  // 💰 СОПРОВОЖДЕНИЕ ПОЗИЦИИ (TP1 → TP2 → TP3 → Trailing)
  // ==========================================================

  /// TP1: +15% от входа, фиксируем 30%, стоп → безубыток.
  static const double TP1_MULTIPLIER = 1.15;
  static const double TP1_CLOSE_SHARE = 0.30;

  /// TP2: +35% от входа, фиксируем ещё 30%, стоп → TP1.
  static const double TP2_MULTIPLIER = 1.35;
  static const double TP2_CLOSE_SHARE = 0.30;

  /// TP3: +75% от входа, активируется Trailing Stop.
  static const double TP3_MULTIPLIER = 1.75;

  /// Trailing Stop: 15% от максимума после TP3.
  static const double TRAILING_PERCENT = 0.15;

  /// Стоп-лосс по умолчанию: ниже pattern_low на 3%.
  static const double SL_PATTERN_LOW_MULTIPLIER = 0.97;

  /// Стоп-лосс по умолчанию (если pattern_low не найден): -5% от входа.
  static const double SL_FALLBACK_MULTIPLIER = 0.95;

  // ==========================================================
  // 🛑 ЗАЩИТА ОТ ПРОБОЯ ИСТОРИЧЕСКОГО ДНА
  // ==========================================================

  /// Макс. доля нижней тени от диапазона свечи при пробое дна.
  /// Если тень больше — пробой не считается «сильным».
  static const double MAX_SHADOW_PCT_ON_BREAKOUT = 0.05;

  // ==========================================================
  // 💵 ДЕМО-РЕЖИМ (Paper Trading)
  // ==========================================================

  /// Стартовый виртуальный баланс (USDT).
  static const double PAPER_START_BALANCE_USDT = 1000.0;

  /// Код валюты для отображения.
  static const String CURRENCY_USDT = 'USDT';
  static const String CURRENCY_USD = 'USD';
  static const String CURRENCY_RUB = 'RUB';

  // ==========================================================
  // 🌐 BYBIT API
  // ==========================================================

  /// Базовый REST-URL Bybit V5 (mainnet).
  static const String BYBIT_BASE_URL = 'https://api.bybit.com';

  /// WebSocket-URL (понадобится позже).
  static const String BYBIT_WS_URL = 'wss://stream.bybit.com/v5/public/linear';

  /// Категория торговли (linear = USDT-перпы).
  static const String BYBIT_CATEGORY = 'linear';

  // ==========================================================
  // 🌍 ВНЕШНИЕ API
  // ==========================================================

  /// API ЦБ РФ для курса USD/RUB. Обновляем раз в сутки.
  static const String CBR_API_URL =
      'https://www.cbr-xml-daily.ru/daily_json.js';

  // ==========================================================
  // ⏰ ВРЕМЯ И ОТЧЁТЫ
  // ==========================================================

  /// Часовой пояс для всех временных меток и отчётов.
  static const String TIMEZONE_MSK = 'Europe/Moscow';

  /// Час отправки ежедневного отчёта (МСК, 24-часовой формат).
  static const int DAILY_REPORT_HOUR = 22;

  /// Минута отправки ежедневного отчёта.
  static const int DAILY_REPORT_MINUTE = 0;

  // ==========================================================
  // 💾 ИМЕНА БОКСОВ HIVE (локальная база данных)
  // ==========================================================

  /// Активные (открытые) сделки.
  static const String BOX_ACTIVE_TRADES = 'box_active_trades';

  /// Монеты на наблюдении (сетапы без входа).
  static const String BOX_WATCHED_SETUPS = 'box_watched_setups';

  /// Закрытые сделки (история).
  static const String BOX_TRADE_HISTORY = 'box_trade_history';

  /// Настройки бота (фильтры, режим торговли, ключи API — только не секреты).
  static const String BOX_SETTINGS = 'box_settings';

  /// История изменения баланса (для графика на экране статистики).
  static const String BOX_BALANCE_HISTORY = 'box_balance_history';

  /// Журнал уведомлений (для экрана «События» — опционально).
  static const String BOX_EVENT_LOG = 'box_event_log';

  // ==========================================================
  // 🔐 КЛЮЧИ БЕЗОПАСНОГО ХРАНИЛИЩА (flutter_secure_storage)
  // ==========================================================

  static const String SECURE_KEY_BYBIT_API = 'bybit_api_key';
  static const String SECURE_KEY_BYBIT_SECRET = 'bybit_api_secret';

  // ==========================================================
  // 🔔 КАНАЛЫ УВЕДОМЛЕНИЙ (flutter_local_notifications)
  // ==========================================================

  /// Основной канал сигналов (вход/наблюдение).
  static const String NOTIF_CHANNEL_SIGNALS_ID = 'einstein_signals';
  static const String NOTIF_CHANNEL_SIGNALS_NAME = 'Сигналы бота';
  static const String NOTIF_CHANNEL_SIGNALS_DESC = 'Сетапы, входы, наблюдения';

  /// Канал фиксаций (TP1, TP2, TP3, стопы).
  static const String NOTIF_CHANNEL_TRADES_ID = 'einstein_trades';
  static const String NOTIF_CHANNEL_TRADES_NAME = 'Сделки';
  static const String NOTIF_CHANNEL_TRADES_DESC = 'Взятие TP, стопы, трейлинг';

  /// Канал отчётов (ежедневный отчёт 22:00 МСК).
  static const String NOTIF_CHANNEL_REPORTS_ID = 'einstein_reports';
  static const String NOTIF_CHANNEL_REPORTS_NAME = 'Отчёты';
  static const String NOTIF_CHANNEL_REPORTS_DESC = 'Ежедневная статистика';

  /// ID канала уведомления Foreground Service (иконка бота в шторке).
  static const String NOTIF_CHANNEL_SERVICE_ID = 'einstein_service';
  static const String NOTIF_CHANNEL_SERVICE_NAME = 'Сервис бота';
  static const String NOTIF_CHANNEL_SERVICE_DESC =
      'Постоянное уведомление о работе торгового движка';

  // ==========================================================
  // 🔢 ID УВЕДОМЛЕНИЙ (уникальные номера для каждого типа)
  // ==========================================================
  static const int NOTIF_ID_SERVICE = 1000;
  static const int NOTIF_ID_SIGNAL = 1001;
  static const int NOTIF_ID_TP = 1002;
  static const int NOTIF_ID_SL = 1003;
  static const int NOTIF_ID_REPORT = 1004;
}