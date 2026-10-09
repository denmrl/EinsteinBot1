// ==========================================================
//  ЭЙНШТЕЙН — Экран управления ботом (совместимо с Flutter 3.24)
//  Файл: lib/presentation/screens/trading_mode_screen.dart
// ==========================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/bot_status_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/sources/bybit_api.dart';
import '../../data/sources/bybit_trading_service.dart';

class TradingModeScreen extends StatefulWidget {
  const TradingModeScreen({super.key});

  @override
  State<TradingModeScreen> createState() => _TradingModeScreenState();
}

class _TradingModeScreenState extends State<TradingModeScreen> {
  final _apiKeyCtrl = TextEditingController();
  final _apiSecretCtrl = TextEditingController();
  bool _obscureSecret = true;
  bool _savingKeys = false;
  bool _checkingConnection = false;

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _apiSecretCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveKeys() async {
    final apiKey = _apiKeyCtrl.text.trim();
    final apiSecret = _apiSecretCtrl.text.trim();

    if (apiKey.isEmpty || apiSecret.isEmpty) {
      _snack('Заполните оба поля', isError: true);
      return;
    }

    setState(() => _savingKeys = true);
    try {
      final settings = context.read<SettingsProvider>();
      await settings.saveBybitKeys(apiKey: apiKey, apiSecret: apiSecret);

      if (settings.environment == BybitEnvironment.mainnet) {
        BybitTradingService.instance.switchToMainnet();
      } else {
        BybitTradingService.instance.switchToTestnet();
      }
      BybitApi.instance.setCredentials(
          apiKey: apiKey, apiSecret: apiSecret);

      _snack('Ключи сохранены ✅');
    } catch (e) {
      _snack('Ошибка сохранения: $e', isError: true);
    } finally {
      if (mounted) setState(() => _savingKeys = false);
    }
  }

  Future<void> _checkConnection() async {
    setState(() => _checkingConnection = true);
    try {
      final tickers = await BybitApi.instance.getTickers();
      if (tickers.isEmpty) {
        _snack('Bybit вернул пустой ответ', isError: true);
        return;
      }
      if (BybitApi.instance.hasCredentials) {
        final bal = await BybitTradingService.instance.getWalletBalanceUsdt();
        _snack('Подключено ✅ Баланс: ${bal.toStringAsFixed(2)} USDT');
      } else {
        _snack('Публичный API OK ✅ Ключи не заданы');
      }
    } catch (e) {
      _snack('Ошибка подключения: $e', isError: true);
    } finally {
      if (mounted) setState(() => _checkingConnection = false);
    }
  }

  Future<bool> _confirmRealMoney() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('⚠️ Реальные деньги!',
            style: TextStyle(color: AppColors.accentRed)),
        content: const Text(
          'Бот будет торговать на РЕАЛЬНОМ счёте Bybit.',
          style: TextStyle(color: AppColors.darkTextPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Понимаю, продолжить'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final bot = context.watch<BotStatusProvider>();
    final isReal = settings.tradingMode == TradingMode.real;
    final isMainnet = settings.environment == BybitEnvironment.mainnet;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(title: const Text('Режим торговли')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _BigToggleCard(
            running: bot.isRunning,
            busy: bot.isBusy,
            isReal: isReal,
            isMainnet: isMainnet,
            onToggle: (value) async {
              if (value && isReal && isMainnet) {
                final ok = await _confirmRealMoney();
                if (!ok) return;
              }
              if (!mounted) return;
              await context.read<BotStatusProvider>().toggle(value);
            },
          ),
          _SectionTitle('Режим торговли'),
          _SegmentedRow<TradingMode>(
            values: const [TradingMode.paper, TradingMode.real],
            current: settings.tradingMode,
            labelOf: (m) => m == TradingMode.paper
                ? 'Paper (демо)'
                : 'Real (реальный)',
            iconOf: (m) => m == TradingMode.paper
                ? Icons.science_outlined
                : Icons.bolt,
            colorOf: (m) => m == TradingMode.paper
                ? AppColors.accentBlue
                : AppColors.accentRed,
            onChanged: (m) async {
              if (bot.isRunning) {
                final ok = await _confirmStop();
                if (!ok) return;
                await context.read<BotStatusProvider>().stop();
              }
              if (!mounted) return;
              await settings.setTradingMode(m);
            },
          ),
          if (isReal) ...[
            _SectionTitle('Контур Bybit'),
            _SegmentedRow<BybitEnvironment>(
              values: const [
                BybitEnvironment.testnet,
                BybitEnvironment.mainnet,
              ],
              current: settings.environment,
              labelOf: (e) => e == BybitEnvironment.testnet
                  ? 'Testnet'
                  : 'Mainnet',
              iconOf: (e) => e == BybitEnvironment.testnet
                  ? Icons.bug_report_outlined
                  : Icons.public,
              colorOf: (e) => e == BybitEnvironment.testnet
                  ? AppColors.accentYellow
                  : AppColors.accentRed,
              onChanged: (e) async {
                if (bot.isRunning) {
                  final ok = await _confirmStop();
                  if (!ok) return;
                  await context.read<BotStatusProvider>().stop();
                }
                if (!mounted) return;
                await settings.setEnvironment(e);
                if (e == BybitEnvironment.mainnet) {
                  BybitTradingService.instance.switchToMainnet();
                } else {
                  BybitTradingService.instance.switchToTestnet();
                }
              },
            ),
            _SectionTitle('API-ключи Bybit'),
            _ApiKeysCard(
              keyCtrl: _apiKeyCtrl,
              secretCtrl: _apiSecretCtrl,
              obscureSecret: _obscureSecret,
              hasSavedKeys: settings.hasBybitCredentials,
              saving: _savingKeys,
              checking: _checkingConnection,
              onToggleObscure: () =>
                  setState(() => _obscureSecret = !_obscureSecret),
              onSave: _saveKeys,
              onCheck: _checkConnection,
              onClear: () async {
                final ok = await _confirmClear();
                if (!ok) return;
                await settings.clearBybitKeys();
                _apiKeyCtrl.clear();
                _apiSecretCtrl.clear();
                _snack('Ключи удалены');
              },
            ),
            if (isMainnet)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.accentRed.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.accentRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Mainnet = реальные деньги. Убедитесь, что ключ '
                        'имеет только права Contract Trade.',
                        style: TextStyle(
                          color: AppColors.accentRed.withOpacity(0.9),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.accentBlue.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.accentBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Paper Trading: виртуальный баланс '
                      '${AppConstants.PAPER_START_BALANCE_USDT.toStringAsFixed(0)} USDT.',
                      style: const TextStyle(
                        color: AppColors.darkTextPrimary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<bool> _confirmStop() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Остановить бота?'),
        content: const Text(
          'Активные сделки останутся открытыми.',
          style: TextStyle(color: AppColors.darkTextPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Остановить'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<bool> _confirmClear() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Удалить API-ключи?'),
        content: const Text(
          'Ключи будут стёрты из памяти.',
          style: TextStyle(color: AppColors.darkTextPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor:
          isError ? AppColors.accentRed : AppColors.accentGreen,
      content: Text(msg),
    ));
  }
}

// ==========================================================
// 🎛 КРУПНЫЙ ТУМБЛЕР
// ==========================================================
class _BigToggleCard extends StatelessWidget {
  final bool running;
  final bool busy;
  final bool isReal;
  final bool isMainnet;
  final ValueChanged<bool> onToggle;

  const _BigToggleCard({
    required this.running,
    required this.busy,
    required this.isReal,
    required this.isMainnet,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final accent = running
        ? (isReal && isMainnet
            ? AppColors.accentRed
            : AppColors.accentGreen)
        : AppColors.darkTextSecondary;

    final status = busy
        ? 'Запускаю...'
        : (running ? 'Бот работает' : 'Бот остановлен');

    final hint = running
        ? (isReal && isMainnet
            ? 'Реальная торговля на MAINNET'
            : (isReal ? 'Реальная торговля на TESTNET' : 'Демо-режим'))
        : 'Нажмите, чтобы запустить';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withOpacity(running ? 0.6 : 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: busy
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: accent,
                    ),
                  )
                : Icon(
                    running ? Icons.pause_circle : Icons.play_circle,
                    size: 36,
                    color: accent,
                  ),
          ),
          const SizedBox(height: 14),
          Text(
            status,
            style: TextStyle(
              color: accent,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(
              color: AppColors.darkTextSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Transform.scale(
            scale: 1.35,
            child: Switch(
              value: running,
              onChanged: busy ? null : onToggle,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.darkTextSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SegmentedRow<T> extends StatelessWidget {
  final List<T> values;
  final T current;
  final String Function(T) labelOf;
  final IconData Function(T) iconOf;
  final Color Function(T) colorOf;
  final ValueChanged<T> onChanged;

  const _SegmentedRow({
    required this.values,
    required this.current,
    required this.labelOf,
    required this.iconOf,
    required this.colorOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: values.map((v) {
          final selected = v == current;
          final color = colorOf(v);
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: selected
                      ? Border.all(color: color.withOpacity(0.5))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      iconOf(v),
                      size: 16,
                      color: selected
                          ? color
                          : AppColors.darkTextSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      labelOf(v),
                      style: TextStyle(
                        color: selected
                            ? color
                            : AppColors.darkTextSecondary,
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ApiKeysCard extends StatelessWidget {
  final TextEditingController keyCtrl;
  final TextEditingController secretCtrl;
  final bool obscureSecret;
  final bool hasSavedKeys;
  final bool saving;
  final bool checking;
  final VoidCallback onToggleObscure;
  final VoidCallback onSave;
  final VoidCallback onCheck;
  final VoidCallback onClear;

  const _ApiKeysCard({
    required this.keyCtrl,
    required this.secretCtrl,
    required this.obscureSecret,
    required this.hasSavedKeys,
    required this.saving,
    required this.checking,
    required this.onToggleObscure,
    required this.onSave,
    required this.onCheck,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasSavedKeys ? Icons.verified_user : Icons.lock_outline,
                size: 16,
                color: hasSavedKeys
                    ? AppColors.accentGreen
                    : AppColors.darkTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                hasSavedKeys ? 'Ключи сохранены' : 'Ключи не заданы',
                style: TextStyle(
                  color: hasSavedKeys
                      ? AppColors.accentGreen
                      : AppColors.darkTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: keyCtrl,
            style: const TextStyle(color: AppColors.darkTextPrimary),
            decoration: const InputDecoration(
              labelText: 'API Key',
              prefixIcon: Icon(Icons.key, size: 18),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: secretCtrl,
            obscureText: obscureSecret,
            style: const TextStyle(color: AppColors.darkTextPrimary),
            decoration: InputDecoration(
              labelText: 'API Secret',
              prefixIcon: const Icon(Icons.password, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureSecret
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                ),
                onPressed: onToggleObscure,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(saving ? 'Сохраняю...' : 'Сохранить'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Проверить подключение',
                onPressed: checking ? null : onCheck,
                icon: checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering),
              ),
              if (hasSavedKeys)
                IconButton(
                  tooltip: 'Удалить ключи',
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.accentRed),
                ),
            ],
          ),
        ],
      ),
    );
  }
}