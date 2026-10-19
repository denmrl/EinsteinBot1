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
  // Контроллеры для текстовых полей
  late final _profileNameCtrl = TextEditingController();
  late final _minTurnoverCtrl = TextEditingController();
  late final _maxTurnoverCtrl = TextEditingController();
  late final _minOiCtrl = TextEditingController();
  late final _capMultCtrl = TextEditingController();
  late final _minEstCapCtrl = TextEditingController();
  late final _maxEstCapCtrl = TextEditingController();
  late final _minRealCapCtrl = TextEditingController();
  late final _maxRealCapCtrl = TextEditingController();
  late final _flagImpulseCtrl = TextEditingController();
  late final _vrevWickCtrl = TextEditingController();
  late final _vrevVolCtrl = TextEditingController();

  // Стейт для ползунков и тумблеров
  double _leverage = 3;
  double _riskPct = 5.0;
  double _tp1 = 1.15;
  double _tp2 = 1.35;
  double _tp3 = 1.75;
  double _trailing = 0.15;
  bool _skipUnlocks = true;

  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillFromSettings());
  }

  @override
  void dispose() {
    _profileNameCtrl.dispose();
    _minTurnoverCtrl.dispose();
    _maxTurnoverCtrl.dispose();
    _minOiCtrl.dispose();
    _capMultCtrl.dispose();
    _minEstCapCtrl.dispose();
    _maxEstCapCtrl.dispose();
    _minRealCapCtrl.dispose();
    _maxRealCapCtrl.dispose();
    _flagImpulseCtrl.dispose();
    _vrevWickCtrl.dispose();
    _vrevVolCtrl.dispose();
    super.dispose();
  }

  void _fillFromSettings() {
    final s = context.read<SettingsProvider>().settings;
    _minTurnoverCtrl.text = s.minTurnover24h.toStringAsFixed(0);
    _maxTurnoverCtrl.text = s.maxTurnover24h.toStringAsFixed(0);
    _minOiCtrl.text = s.minOpenInterest.toStringAsFixed(0);
    _capMultCtrl.text = s.capMultiplier.toString();
    _minEstCapCtrl.text = s.minEstimatedCap.toStringAsFixed(0);
    _maxEstCapCtrl.text = s.maxEstimatedCap.toStringAsFixed(0);
    _minRealCapCtrl.text = s.minRealMarketCap.toStringAsFixed(0);
    _maxRealCapCtrl.text = s.maxRealMarketCap.toStringAsFixed(0);
    _flagImpulseCtrl.text = s.flagMinImpulse.toString();
    _vrevWickCtrl.text = s.vrevWickBodyRatio.toString();
    _vrevVolCtrl.text = s.vrevVolumeSpike.toString();
    
    setState(() {
      _leverage = s.leverage.toDouble();
      _riskPct = s.riskPerTradePct;
      _tp1 = s.tp1Multiplier;
      _tp2 = s.tp2Multiplier;
      _tp3 = s.tp3Multiplier;
      _trailing = s.trailingPercent;
      _skipUnlocks = s.skipUpcomingUnlocks;
      _dirty = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final current = context.read<SettingsProvider>().settings;
      final updated = current.copyWith(
        minTurnover24h: _parse(_minTurnoverCtrl.text, current.minTurnover24h),
        maxTurnover24h: _parse(_maxTurnoverCtrl.text, current.maxTurnover24h),
        minOpenInterest: _parse(_minOiCtrl.text, current.minOpenInterest),
        capMultiplier: _parse(_capMultCtrl.text, current.capMultiplier),
        minEstimatedCap: _parse(_minEstCapCtrl.text, current.minEstimatedCap),
        maxEstimatedCap: _parse(_maxEstCapCtrl.text, current.maxEstimatedCap),
        minRealMarketCap: _parse(_minRealCapCtrl.text, current.minRealMarketCap),
        maxRealMarketCap: _parse(_maxRealCapCtrl.text, current.maxRealMarketCap),
        skipUpcomingUnlocks: _skipUnlocks,
        flagMinImpulse: _parse(_flagImpulseCtrl.text, current.flagMinImpulse),
        vrevWickBodyRatio: _parse(_vrevWickCtrl.text, current.vrevWickBodyRatio),
        vrevVolumeSpike: _parse(_vrevVolCtrl.text, current.vrevVolumeSpike),
        leverage: _leverage.round(),
        riskPerTradePct: _riskPct,
        tp1Multiplier: _tp1,
        tp2Multiplier: _tp2,
        tp3Multiplier: _tp3,
        trailingPercent: _trailing,
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

  Future<void> _saveProfile() async {
    final name = _profileNameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Введите название профиля', isError: true);
      return;
    }
    await _save(); // Сначала сохраняем текущие настройки
    if (!mounted) return;
    await context.read<SettingsProvider>().saveCurrentAsProfile(name);
    _profileNameCtrl.clear();
    _snack('Профиль "$name" сохранен ✅');
  }

  Future<void> _resetBalance() async {
    final ok = await _confirm('Сбросить демо-баланс?', 'Виртуальный баланс вернётся к 1000 USDT.');
    if (!ok) return;
    await context.read<SettingsProvider>().resetPaperAccount();
    if (!mounted) return;
    _snack('Баланс сброшен ✅');
  }

  Future<void> _clearHistory() async {
    final ok = await _confirm('Очистить историю?', 'Все закрытые сделки будут удалены.');
    if (!ok) return;
    await context.read<TradesProvider>().clearHistory();
    if (!mounted) return;
    _snack('История очищена ✅');
  }

  Future<bool> _confirm(String title, String message) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: Text(title, style: const TextStyle(color: AppColors.accentRed)),
        content: Text(message, style: const TextStyle(color: AppColors.darkTextPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
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
      backgroundColor: isError ? AppColors.accentRed : AppColors.accentGreen,
      content: Text(msg),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: const Text('Настройки бота'),
        actions: [
          TextButton(
            onPressed: (_dirty && !_saving) ? _save : null,
            child: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Сохранить', style: TextStyle(
                    color: _dirty ? AppColors.accentGreen : AppColors.darkTextSecondary,
                    fontWeight: FontWeight.w600,
                  )),
          ),
        ],
      ),
      body: settings.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentGreen))
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // ==========================================================
                // 📁 ПРОФИЛИ СТРАТЕГИЙ
                // ==========================================================
                _SectionCard(
                  icon: Icons.folder_special_outlined,
                  title: 'Стратегии',
                  subtitle: 'Сохранение и переключение профилей',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _profileNameCtrl,
                            style: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Название (напр. Агрессивная)',
                              hintStyle: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _saveProfile,
                          icon: const Icon(Icons.save, color: AppColors.accentBlue),
                          tooltip: 'Сохранить профиль',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (settings.profileNames.isEmpty)
                      const Text('Нет сохраненных профилей', style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 12))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: settings.profileNames.map((name) {
                          return InputChip(
                            label: Text(name, style: const TextStyle(fontSize: 12)),
                            onPressed: () async {
                              await settings.applyProfile(name);
                              _fillFromSettings();
                              _snack('Профиль "$name" активирован ⚡');
                            },
                            onDeleted: () async {
                              await settings.deleteProfile(name);
                              _snack('Профиль удален');
                            },
                            deleteIconColor: AppColors.accentRed,
                            backgroundColor: AppColors.darkSurfaceElevated,
                            side: const BorderSide(color: AppColors.darkBorder),
                          );
                        }).toList(),
                      ),
                  ],
                ),

                // ==========================================================
                // 💧 ФИЛЬТРЫ
                // ==========================================================
                _SectionCard(
                  icon: Icons.filter_alt_outlined,
                  title: 'Фильтры (Bybit)',
                  subtitle: 'Оборот, OI и капа',
                  children: [
                    _NumberField(label: 'Мин. оборот 24ч', controller: _minTurnoverCtrl, onChanged: () => setState(() => _dirty = true)),
                    _NumberField(label: 'Макс. оборот 24ч', controller: _maxTurnoverCtrl, onChanged: () => setState(() => _dirty = true)),
                    _NumberField(label: 'Мин. OI', controller: _minOiCtrl, onChanged: () => setState(() => _dirty = true)),
                    _NumberField(label: 'Коэфф. капы (×оборот)', controller: _capMultCtrl, onChanged: () => setState(() => _dirty = true)),
                    _NumberField(label: 'Мин. оценочная капа', controller: _minEstCapCtrl, onChanged: () => setState(() => _dirty = true)),
                    _NumberField(label: 'Макс. оценочная капа', controller: _maxEstCapCtrl, onChanged: () => setState(() => _dirty = true)),
                  ],
                ),

                // ==========================================================
                // 🌐 ВНЕШНИЕ ДАННЫЕ
                // ==========================================================
                _SectionCard(
                  icon: Icons.public,
                  title: 'Внешние данные (CoinGecko / Unlocks)',
                  subtitle: 'Точная капитализация и разблокировки',
                  children: [
                    _NumberField(label: 'Мин. реальная капа (USD)', controller: _minRealCapCtrl, onChanged: () => setState(() => _dirty = true)),
                    _NumberField(label: 'Макс. реальная капа (USD)', controller: _maxRealCapCtrl, onChanged: () => setState(() => _dirty = true)),
                    SwitchListTile(
                      title: const Text('Пропускать монеты с разблокировкой', style: TextStyle(color: AppColors.darkTextPrimary, fontSize: 14)),
                      value: _skipUnlocks,
                      activeColor: AppColors.accentGreen,
                      onChanged: (v) => setState(() { _skipUnlocks = v; _dirty = true; }),
                    ),
                  ],
                ),

                // ==========================================================
                // 📐 ПАТТЕРНЫ
                // ==========================================================
                _SectionCard(
                  icon: Icons.auto_graph,
                  title: 'Параметры паттернов',
                  children: [
                    _NumberField(label: 'Импульс Флага', controller: _flagImpulseCtrl, onChanged: () => setState(() => _dirty = true)),
                    _NumberField(label: 'V-Разворот: тень / тело', controller: _vrevWickCtrl, onChanged: () => setState(() => _dirty = true)),
                    _NumberField(label: 'V-Разворот: спайк объема', controller: _vrevVolCtrl, onChanged: () => setState(() => _dirty = true)),
                  ],
                ),

                // ==========================================================
                // 🛡 РИСК-МЕНЕДЖМЕНТ И ФИКСАЦИИ
                // ==========================================================
                _SectionCard(
                  icon: Icons.shield_outlined,
                  title: 'Риск и Фиксации',
                  subtitle: 'Плечо, TP и Трейлинг',
                  children: [
                    _SliderField(
                      label: 'Кредитное плечо', valueLabel: '${_leverage.round()}x',
                      value: _leverage, min: 1, max: 20, divisions: 19,
                      onChanged: (v) => setState(() { _leverage = v; _dirty = true; }),
                    ),
                    _SliderField(
                      label: 'Риск на сделку', valueLabel: '${_riskPct.toStringAsFixed(1)}%',
                      value: _riskPct, min: 1, max: 20, divisions: 38,
                      onChanged: (v) => setState(() { _riskPct = v; _dirty = true; }),
                    ),
                    const Divider(color: AppColors.darkBorder, height: 24),
                    _SliderField(
                      label: 'TP1 (Фиксация 30%)', valueLabel: '${(_tp1*100 - 100).toStringAsFixed(0)}%',
                      value: _tp1, min: 1.05, max: 1.5, divisions: 45,
                      onChanged: (v) => setState(() { _tp1 = v; _dirty = true; }),
                    ),
                    _SliderField(
                      label: 'TP2 (Фиксация 30%)', valueLabel: '${(_tp2*100 - 100).toStringAsFixed(0)}%',
                      value: _tp2, min: 1.2, max: 2.0, divisions: 80,
                      onChanged: (v) => setState(() { _tp2 = v; _dirty = true; }),
                    ),
                    _SliderField(
                      label: 'TP3 (Вкл. трейлинг)', valueLabel: '${(_tp3*100 - 100).toStringAsFixed(0)}%',
                      value: _tp3, min: 1.5, max: 3.0, divisions: 75,
                      onChanged: (v) => setState(() { _tp3 = v; _dirty = true; }),
                    ),
                    _SliderField(
                      label: 'Трейлинг от максимума', valueLabel: '${(_trailing*100).toStringAsFixed(0)}%',
                      value: _trailing, min: 0.05, max: 0.3, divisions: 25,
                      onChanged: (v) => setState(() { _trailing = v; _dirty = true; }),
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
                    color: AppColors.accentRed.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accentRed.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppColors.accentRed, size: 18),
                          SizedBox(width: 8),
                          Text('ОПАСНАЯ ЗОНА', style: TextStyle(color: AppColors.accentRed, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _DangerButton(icon: Icons.restart_alt, label: 'Сбросить демо-баланс к 1000\$', onTap: _resetBalance),
                      const SizedBox(height: 8),
                      _DangerButton(icon: Icons.delete_sweep_outlined, label: 'Очистить историю сделок', onTap: _clearHistory),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final List<Widget> children;
  const _SectionCard({required this.icon, required this.title, this.subtitle = '', required this.children});

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
                width: 32, height: 32,
                decoration: BoxDecoration(color: AppColors.accentBlue.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: AppColors.accentBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                    if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 11)),
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

class _NumberField extends StatelessWidget {
  final String label; final TextEditingController controller; final VoidCallback onChanged;
  const _NumberField({required this.label, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        onChanged: (_) => onChanged(),
        style: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 14),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  final String label; final String valueLabel; final double value;
  final double min; final double max; final int divisions; final ValueChanged<double> onChanged;
  const _SliderField({required this.label, required this.valueLabel, required this.value, required this.min, required this.max, required this.divisions, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 13))),
              Text(valueLabel, style: const TextStyle(color: AppColors.accentGreen, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: value, min: min, max: max, divisions: divisions,
            activeColor: AppColors.accentGreen, inactiveColor: AppColors.darkBorder,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _DangerButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: AppColors.accentRed),
        label: Align(alignment: Alignment.centerLeft, child: Text(label, style: const TextStyle(color: AppColors.accentRed))),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          side: BorderSide(color: AppColors.accentRed.withOpacity(0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
