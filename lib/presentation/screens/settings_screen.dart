// ==========================================================
//  ЭЙНШТЕЙН — Экран настроек фильтров и риск-менеджмента
//  Файл: lib/presentation/screens/settings_screen.dart
//  Разделы:
//    1. Фильтры ликвидности (оборот / OI / капа).
//    2. Параметры паттернов (импульс флага, V-разворот).
//    3. Риск-менеджмент (плечо, риск на сделку).
//  Плюс опасная зона: сброс демо-баланса и очистка истории.
// ==========================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/trades_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ---------- Контроллеры полей ----------
  late final _minTurnoverCtrl = TextEditingController();
  late final _maxTurnoverCtrl = TextEditingController();
  late final _minOiCtrl = TextEditingController();
  late final _capMultCtrl = TextEditingController();

  late final _flagImpulseCtrl = TextEditingController();
  late final _vrevWickCtrl = TextEditingController();
  late final _vrevVolCtrl = TextEditingController();

  // Плечо и риск — слайдеры (double).
  double _leverage = 3;
  double _riskPct = 5.0;

  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Заполняем поля текущими значениями.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillFromSettings());
  }

  @override
  void dispose() {
    _minTurnoverCtrl.dispose();
    _maxTurnoverCtrl.dispose();
    _minOiCtrl.dispose();
    _capMultCtrl.dispose();
    _flagImpulseCtrl.dispose();
    _vrevWickCtrl.dispose();
    _vrevVolCtrl.dispose();
    super.dispose();
  }

  /// Считываем текущие настройки и раскладываем по полям.
  void _fillFromSettings() {
    final s = context.read<SettingsProvider>().settings;
    _minTurnoverCtrl.text = s.minTurnover24h.toStringAsFixed(0);
    _maxTurnoverCtrl.text = s.maxTurnover24h.toStringAsFixed(0);
    _minOiCtrl.text = s.minOpenInterest.toStringAsFixed(0);
    _capMultCtrl.text = s.capMultiplier.toString();
    _flagImpulseCtrl.text = s.flagMinImpulse.toString();
    _vrevWickCtrl.text = s.vrevWickBodyRatio.toString();
    _vrevVolCtrl.text = s.vrevVolumeSpike.toString();
    setState(() {
      _leverage = s.leverage.toDouble();
      _riskPct = s.riskPerTradePct;
      _dirty = false;
    });
  }

  // ==========================================================
  // 💾 СОХРАНЕНИЕ ИЗМЕНЕНИЙ
  // ==========================================================
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final current = context.read<SettingsProvider>().settings;

      final updated = current.copyWith(
        minTurnover24h: _parse(_minTurnoverCtrl.text, current.minTurnover24h),
        maxTurnover24h: _parse(_maxTurnoverCtrl.text, current.maxTurnover24h),
        minOpenInterest: _parse(_minOiCtrl.text, current.minOpenInterest),
        capMultiplier: _parse(_capMultCtrl.text, current.capMultiplier),
        flagMinImpulse: _parse(_flagImpulseCtrl.text, current.flagMinImpulse),
        vrevWickBodyRatio:
            _parse(_vrevWickCtrl.text, current.vrevWickBodyRatio),
        vrevVolumeSpike:
            _parse(_vrevVolCtrl.text, current.vrevVolumeSpike),
        leverage: _leverage.round(),
        riskPerTradePct: _riskPct,
      );

      await context.read<SettingsProvider>().updateSettings(updated);
      _snack('Настройки сохранены ✅');
      setState(() => _dirty = false);
    } catch (e) {
      _snack('Ошибка сохранения: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double _parse(String raw, double fallback) {
    final v = double.tryParse(raw.replaceAll(',', '.').trim());
    return v ?? fallback;
  }

  // ==========================================================
  // ⚠️ ОПАСНАЯ ЗОНА — СБРОС
  // ==========================================================
  Future<void> _resetBalance() async {
    final ok = await _confirm(
      title: 'Сбросить демо-баланс?',
      message: 'Виртуальный баланс вернётся к '
          '${AppConstants.PAPER_START_BALANCE_USDT.toStringAsFixed(0)} USDT, '
          'история изменения баланса будет очищена.',
    );
    if (!ok) return;
    await context.read<SettingsProvider>().resetPaperAccount();
    if (!mounted) return;
    _snack('Баланс сброшен к 1000 USDT ✅');
  }

  Future<void> _clearHistory() async {
    final ok = await _confirm(
      title: 'Очистить историю сделок?',
      message: 'Все закрытые сделки будут удалены. '
          'Винрейт и статистика обнулятся.',
    );
    if (!ok) return;
    await context.read<TradesProvider>().clearHistory();
    if (!mounted) return;
    _snack('История очищена ✅');
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: Text(title, style: const TextStyle(color: AppColors.accentRed)),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.darkTextPrimary),
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
            child: const Text('Подтвердить'),
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

  // ==========================================================
  // 🎨 UI
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: const Text('Настройки бота'),
        actions: [
          // Кнопка сохранения активна только при изменениях.
          TextButton(
            onPressed: (_dirty && !_saving) ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Сохранить',
                    style: TextStyle(
                      color: _dirty
                          ? AppColors.accentGreen
                          : AppColors.darkTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: settings.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.accentGreen,
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // ==========================================================
                // 💧 ФИЛЬТРЫ ЛИКВИДНОСТИ
                // ==========================================================
                _SectionCard(
                  icon: Icons.water_drop_outlined,
                  title: 'Фильтры ликвидности',
                  subtitle: 'Отбор монет по обороту, OI и оценочной капе',
                  children: [
                    _NumberField(
                      label: 'Мин. оборот 24ч, USDT',
                      hint: 'например 300000',
                      controller: _minTurnoverCtrl,
                      onChanged: () => setState(() => _dirty = true),
                    ),
                    _NumberField(
                      label: 'Макс. оборот 24ч, USDT',
                      hint: 'например 40000000',
                      controller: _maxTurnoverCtrl,
                      onChanged: () => setState(() => _dirty = true),
                    ),
                    _NumberField(
                      label: 'Мин. Open Interest, USDT',
                      hint: 'например 100000',
                      controller: _minOiCtrl,
                      onChanged: () => setState(() => _dirty = true),
                    ),
                    _NumberField(
                      label: 'Коэффициент капы (×оборот)',
                      hint: 'например 3.5',
                      controller: _capMultCtrl,
                      onChanged: () => setState(() => _dirty = true),
                    ),
                  ],
                ),

                // ==========================================================
                // 📐 ПАРАМЕТРЫ ПАТТЕРНОВ
                // ==========================================================
                _SectionCard(
                  icon: Icons.auto_graph,
                  title: 'Параметры паттернов',
                  subtitle: 'Чувствительность распознавания формаций',
                  children: [
                    _NumberField(
                      label: 'Импульс Бычьего Флага (доля)',
                      hint: '0.08 = 8% роста до консолидации',
                      controller: _flagImpulseCtrl,
                      onChanged: () => setState(() => _dirty = true),
                    ),
                    _NumberField(
                      label: 'V-Разворот: тень / тело',
                      hint: '1.6 = тень в 1.6 раза больше тела',
                      controller: _vrevWickCtrl,
                      onChanged: () => setState(() => _dirty = true),
                    ),
                    _NumberField(
                      label: 'V-Разворот: спайк объёма',
                      hint: '1.8 = объём в 1.8 раза выше среднего',
                      controller: _vrevVolCtrl,
                      onChanged: () => setState(() => _dirty = true),
                    ),
                  ],
                ),

                // ==========================================================
                // 🛡 РИСК-МЕНЕДЖМЕНТ
                // ==========================================================
                _SectionCard(
                  icon: Icons.shield_outlined,
                  title: 'Риск-менеджмент',
                  subtitle: 'Плечо и максимальный риск на сделку',
                  children: [
                    _SliderField(
                      label: 'Кредитное плечо',
                      valueLabel: '${_leverage.round()}x',
                      value: _leverage,
                      min: 1,
                      max: 20,
                      divisions: 19,
                      onChanged: (v) => setState(() {
                        _leverage = v;
                        _dirty = true;
                      }),
                    ),
                    _SliderField(
                      label: 'Риск на сделку',
                      valueLabel: '${_riskPct.toStringAsFixed(1)}%',
                      value: _riskPct,
                      min: 1,
                      max: 20,
                      divisions: 38,
                      onChanged: (v) => setState(() {
                        _riskPct = v;
                        _dirty = true;
                      }),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'При риске $_riskPct% и балансе 1000 USDT максимальный '
                        'убыток по одной сделке ≈ '
                        '${(1000 * _riskPct / 100).toStringAsFixed(1)} USDT',
                        style: const TextStyle(
                          color: AppColors.darkTextSecondary,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),

                // ==========================================================
                // ⚠️ ОПАСНАЯ ЗОНА
                // ==========================================================
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 20, 12, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accentRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: AppColors.accentRed, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'ОПАСНАЯ ЗОНА',
                            style: TextStyle(
                              color: AppColors.accentRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _DangerButton(
                        icon: Icons.restart_alt,
                        label: 'Сбросить демо-баланс к '
                            '${AppConstants.PAPER_START_BALANCE_USDT.toStringAsFixed(0)}\$',
                        onTap: _resetBalance,
                      ),
                      const SizedBox(height: 8),
                      _DangerButton(
                        icon: Icons.delete_sweep_outlined,
                        label: 'Очистить историю сделок',
                        onTap: _clearHistory,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ==========================================================
// 🧱 КАРТОЧКА СЕКЦИИ
// ==========================================================
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(16),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    size: 18, color: AppColors.accentBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.darkTextPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.darkTextSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

// ==========================================================
// 🔢 ЧИСЛОВОЕ ПОЛЕ
// ==========================================================
class _NumberField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _NumberField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        onChanged: (_) => onChanged(),
        style: const TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.darkTextSecondary.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// 🎚 СЛАЙДЕР
// ==========================================================
class _SliderField extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderField({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.darkTextPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: const TextStyle(
                  color: AppColors.accentGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppColors.accentGreen,
            inactiveColor: AppColors.darkBorder,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// ⚠️ КНОПКА ОПАСНОГО ДЕЙСТВИЯ
// ==========================================================
class _DangerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DangerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: AppColors.accentRed),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.accentRed),
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          side: BorderSide(
            color: AppColors.accentRed.withValues(alpha: 0.4),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}