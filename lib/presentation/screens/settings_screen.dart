import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/trades_provider.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  double _leverage = 3; double _riskPct = 5.0;
  double _tp1 = 1.15; double _tp2 = 1.35; double _tp3 = 1.75; double _tp4 = 2.5; double _tp5 = 4.0;
  double _trailing = 0.15;
  bool _skipUnlocks = true; bool _enableTrailing = true;
  int _tpCount = 3;
  bool _dirty = false; bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillFromSettings());
  }

  @override
  void dispose() {
    _profileNameCtrl.dispose(); _minTurnoverCtrl.dispose(); _maxTurnoverCtrl.dispose();
    _minOiCtrl.dispose(); _capMultCtrl.dispose(); _minEstCapCtrl.dispose(); _maxEstCapCtrl.dispose();
    _minRealCapCtrl.dispose(); _maxRealCapCtrl.dispose(); _flagImpulseCtrl.dispose();
    _vrevWickCtrl.dispose(); _vrevVolCtrl.dispose();
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
      _leverage = s.leverage.toDouble(); _riskPct = s.riskPerTradePct;
      _tp1 = s.tp1Multiplier; _tp2 = s.tp2Multiplier; _tp3 = s.tp3Multiplier;
      _tp4 = s.tp4Multiplier; _tp5 = s.tp5Multiplier; _tpCount = s.tpCount;
      _trailing = s.trailingPercent; _skipUnlocks = s.skipUpcomingUnlocks;
      _enableTrailing = s.enableTrailing; _dirty = false;
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
        leverage: _leverage.round(), riskPerTradePct: _riskPct,
        tp1Multiplier: _tp1, tp2Multiplier: _tp2, tp3Multiplier: _tp3,
        tp4Multiplier: _tp4, tp5Multiplier: _tp5, tpCount: _tpCount,
        trailingPercent: _trailing, enableTrailing: _enableTrailing,
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

  double _parse(String raw, double fallback) => double.tryParse(raw.replaceAll(',', '.').trim()) ?? fallback;

  Future<void> _saveProfile() async {
    final name = _profileNameCtrl.text.trim();
    if (name.isEmpty) { _snack('Введите название профиля', isError: true); return; }
    await _save();
    if (!mounted) return;
    await context.read<SettingsProvider>().saveCurrentAsProfile(name);
    _profileNameCtrl.clear();
    _snack('Профиль "$name" сохранен ✅');
  }

  Future<void> _resetBalance() async {
    final ok = await _confirm('Сбросить демо-баланс?', 'Виртуальный баланс вернётся к 1000 USDT.');
    if (!ok) return;
    await context.read<SettingsProvider>().resetPaperAccount();
    if (mounted) _snack('Баланс сброшен ✅');
  }

  Future<void> _clearHistory() async {
    final ok = await _confirm('Очистить историю?', 'Все закрытые сделки будут удалены.');
    if (!ok) return;
    await context.read<TradesProvider>().clearHistory();
    if (mounted) _snack('История очищена ✅');
  }

  Future<bool> _confirm(String title, String message) async {
    final res = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.darkSurface,
      title: Text(title, style: const TextStyle(color: AppColors.accentRed)),
      content: Text(message, style: const TextStyle(color: AppColors.darkTextPrimary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed), onPressed: () => Navigator.pop(ctx, true), child: const Text('Подтвердить')),
      ],
    ));
    return res ?? false;
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: isError ? AppColors.accentRed : AppColors.accentGreen, content: Text(msg),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: const Text('Настройки бота'),
        actions: [TextButton(onPressed: (_dirty && !_saving) ? _save : null, child: Text('Сохранить', style: TextStyle(color: _dirty ? AppColors.accentGreen : AppColors.darkTextSecondary)))],
      ),
      body: settings.isLoading ? const Center(child: CircularProgressIndicator(color: AppColors.accentGreen)) : ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _SectionCard(icon: Icons.folder_special_outlined, title: 'Стратегии', subtitle: 'Профили настроек', children: [
            Row(children: [
              Expanded(child: TextField(controller: _profileNameCtrl, decoration: const InputDecoration(hintText: 'Название профиля...', isDense: true))),
              IconButton(onPressed: _saveProfile, icon: const Icon(Icons.save, color: AppColors.accentBlue)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: settings.profileNames.map((n) => InputChip(
              label: Text(n), onPressed: () { settings.applyProfile(n); _fillFromSettings(); _snack('Профиль активирован'); }, onDeleted: () => settings.deleteProfile(n),
            )).toList()),
          ]),
          _SectionCard(icon: Icons.filter_alt_outlined, title: 'Фильтры (Bybit)', children: [
            _NumberField('Мин. оборот 24ч', _minTurnoverCtrl, () => setState(() => _dirty = true)),
            _NumberField('Макс. оборот 24ч', _maxTurnoverCtrl, () => setState(() => _dirty = true)),
            _NumberField('Мин. OI', _minOiCtrl, () => setState(() => _dirty = true)),
            _NumberField('Коэфф. капы', _capMultCtrl, () => setState(() => _dirty = true)),
          ]),
          _SectionCard(icon: Icons.public, title: 'Внешние данные', children: [
            _NumberField('Мин. реал. капа', _minRealCapCtrl, () => setState(() => _dirty = true)),
            _NumberField('Макс. реал. капа', _maxRealCapCtrl, () => setState(() => _dirty = true)),
            SwitchListTile(title: const Text('Пропускать разблокировки', style: TextStyle(color: AppColors.darkTextPrimary, fontSize: 14)), value: _skipUnlocks, onChanged: (v) => setState(() { _skipUnlocks = v; _dirty = true; })),
          ]),
          
          _SectionCard(icon: Icons.shield_outlined, title: 'Риск и Фиксации', children: [
            _SliderWithInput(label: 'Плечо', value: _leverage, min: 1, max: 20, isInt: true, onChanged: (v) => setState(() { _leverage = v; _dirty = true; })),
            _SliderWithInput(label: 'Риск на сделку (%)', value: _riskPct, min: 1, max: 20, onChanged: (v) => setState(() { _riskPct = v; _dirty = true; })),
            const Divider(color: AppColors.darkBorder, height: 24),
            
            // Выбор количества TP
            Row(children: [
              const Text('Количество TP:', style: TextStyle(color: AppColors.darkTextPrimary)),
              const SizedBox(width: 16),
              DropdownButton<int>(
                value: _tpCount,
                dropdownColor: AppColors.darkSurfaceElevated,
                style: const TextStyle(color: AppColors.accentGreen),
                items: [1, 2, 3, 4, 5].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                onChanged: (v) => setState(() { _tpCount = v!; _dirty = true; }),
              ),
            ]),
            const SizedBox(height: 8),

            if (_tpCount >= 1) _SliderWithInput(label: 'TP1 (%)', value: (_tp1*100)-100, min: 5, max: 50, onChanged: (v) => setState(() { _tp1 = 1 + (v/100); _dirty = true; })),
            if (_tpCount >= 2) _SliderWithInput(label: 'TP2 (%)', value: (_tp2*100)-100, min: 20, max: 100, onChanged: (v) => setState(() { _tp2 = 1 + (v/100); _dirty = true; })),
            if (_tpCount >= 3) _SliderWithInput(label: 'TP3 (%)', value: (_tp3*100)-100, min: 50, max: 200, onChanged: (v) => setState(() { _tp3 = 1 + (v/100); _dirty = true; })),
            if (_tpCount >= 4) _SliderWithInput(label: 'TP4 (%)', value: (_tp4*100)-100, min: 100, max: 300, onChanged: (v) => setState(() { _tp4 = 1 + (v/100); _dirty = true; })),
            if (_tpCount >= 5) _SliderWithInput(label: 'TP5 (%)', value: (_tp5*100)-100, min: 200, max: 500, onChanged: (v) => setState(() { _tp5 = 1 + (v/100); _dirty = true; })),

            const Divider(color: AppColors.darkBorder, height: 24),
            SwitchListTile(title: const Text('Включить Трейлинг-стоп', style: TextStyle(color: AppColors.darkTextPrimary, fontSize: 14)), value: _enableTrailing, activeColor: AppColors.accentGreen, onChanged: (v) => setState(() { _enableTrailing = v; _dirty = true; })),
            if (_enableTrailing) _SliderWithInput(label: 'Трейлинг (%)', value: _trailing*100, min: 5, max: 30, onChanged: (v) => setState(() { _trailing = v/100; _dirty = true; })),
          ]),
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
    return Container(margin: const EdgeInsets.fromLTRB(12, 12, 12, 0), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.darkBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: AppColors.accentBlue), const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14), ...children,
      ]),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label; final TextEditingController controller; final VoidCallback onChanged;
  const _NumberField(this.label, this.controller, this.onChanged);
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(
      controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))], onChanged: (_) => onChanged(),
      decoration: InputDecoration(labelText: label),
    ));
  }
}

// НОВЫЙ ВИДЖЕТ: Слайдер + Ручной ввод
class _SliderWithInput extends StatefulWidget {
  final String label; final double value; final double min; final double max; final bool isInt; final ValueChanged<double> onChanged;
  const _SliderWithInput({required this.label, required this.value, required this.min, required this.max, this.isInt = false, required this.onChanged});
  @override
  State<_SliderWithInput> createState() => _SliderWithInputState();
}

class _SliderWithInputState extends State<_SliderWithInput> {
  late TextEditingController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = TextEditingController(text: _format(widget.value)); }
  @override
  void didUpdateWidget(covariant _SliderWithInput oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.value != widget.value) _ctrl.text = _format(widget.value); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  String _format(double v) => widget.isInt ? v.round().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 13)),
      Row(children: [
        Expanded(child: Slider(value: widget.value, min: widget.min, max: widget.max, activeColor: AppColors.accentGreen, onChanged: widget.onChanged)),
        SizedBox(width: 60, child: TextField(
          controller: _ctrl, keyboardType: TextInputType.number,
          textAlign: TextAlign.center, style: const TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
          onSubmitted: (v) { final parsed = double.tryParse(v); if (parsed != null) widget.onChanged(widget.isInt ? parsed.roundToDouble() : parsed); },
        )),
      ]),
    ]));
  }
}
