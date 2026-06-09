import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/diary_provider.dart';

enum _Sex { male, female }

enum _ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
  extraActive,
}

extension _ActivityLevelExt on _ActivityLevel {
  String get label => switch (this) {
    _ActivityLevel.sedentary => 'Sedentary',
    _ActivityLevel.lightlyActive => 'Lightly active',
    _ActivityLevel.moderatelyActive => 'Moderately active',
    _ActivityLevel.veryActive => 'Very active',
    _ActivityLevel.extraActive => 'Extra active',
  };

  String get description => switch (this) {
    _ActivityLevel.sedentary => 'Little or no exercise',
    _ActivityLevel.lightlyActive => 'Exercise 1–3 days/week',
    _ActivityLevel.moderatelyActive => 'Exercise 3–5 days/week',
    _ActivityLevel.veryActive => 'Exercise 6–7 days/week',
    _ActivityLevel.extraActive => 'Very hard exercise or physical job',
  };

  double get multiplier => switch (this) {
    _ActivityLevel.sedentary => 1.2,
    _ActivityLevel.lightlyActive => 1.375,
    _ActivityLevel.moderatelyActive => 1.55,
    _ActivityLevel.veryActive => 1.725,
    _ActivityLevel.extraActive => 1.9,
  };
}

class BmrCalculatorScreen extends StatefulWidget {
  const BmrCalculatorScreen({super.key});

  @override
  State<BmrCalculatorScreen> createState() => _BmrCalculatorScreenState();
}

class _BmrCalculatorScreenState extends State<BmrCalculatorScreen> {
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  _Sex _sex = _Sex.male;
  _ActivityLevel _activity = _ActivityLevel.moderatelyActive;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final age = prefs.getInt('bmr_age');
      final height = prefs.getInt('bmr_height');
      final weight = prefs.getDouble('bmr_weight');
      if (age != null) _ageCtrl.text = age.toString();
      if (height != null) _heightCtrl.text = height.toString();
      if (weight != null) {
        _weightCtrl.text = weight % 1 == 0
            ? weight.toInt().toString()
            : weight.toString();
      }
      final sexIdx = prefs.getInt('bmr_sex') ?? 0;
      _sex = _Sex.values[sexIdx.clamp(0, _Sex.values.length - 1)];
      final actIdx = prefs.getInt('bmr_activity') ?? 2;
      _activity = _ActivityLevel
          .values[actIdx.clamp(0, _ActivityLevel.values.length - 1)];
    });
    await _savePrefs();
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final age = int.tryParse(_ageCtrl.text);
    final height = int.tryParse(_heightCtrl.text);
    final weight = double.tryParse(_weightCtrl.text);
    if (age != null) await prefs.setInt('bmr_age', age);
    if (height != null) await prefs.setInt('bmr_height', height);
    if (weight != null) await prefs.setDouble('bmr_weight', weight);
    await prefs.setInt('bmr_sex', _sex.index);
    await prefs.setInt('bmr_activity', _activity.index);
    final r = _calculate();
    if (r.bmr != null && r.tdee != null) {
      final roundedBmr = r.bmr!.round();
      final roundedTdee = r.tdee!.round();
      await prefs.setInt('bmr_value', roundedBmr);
      await prefs.setInt('tdee_value', roundedTdee);
      if (mounted) {
        final diary = context.read<DiaryProvider>();
        diary.setBmr(roundedBmr);
        diary.setTdee(roundedTdee);
      }
    }
  }

  ({double? bmi, double? bmr, double? tdee}) _calculate() {
    final age = int.tryParse(_ageCtrl.text);
    final heightCm = int.tryParse(_heightCtrl.text);
    final weightKg = double.tryParse(_weightCtrl.text);
    if (age == null || heightCm == null || weightKg == null) {
      return (bmi: null, bmr: null, tdee: null);
    }
    if (age <= 0 || heightCm <= 0 || weightKg <= 0) {
      return (bmi: null, bmr: null, tdee: null);
    }

    // Mifflin St. Jeor
    final bmr =
        10 * weightKg +
        6.25 * heightCm -
        5 * age +
        (_sex == _Sex.male ? 5 : -161);
    final tdee = bmr * _activity.multiplier;
    final heightM = heightCm / 100;
    final bmi = weightKg / (heightM * heightM);
    return (bmi: bmi, bmr: bmr, tdee: tdee);
  }

  String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal weight';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  Color _bmiColor(BuildContext context, double bmi) {
    final scheme = Theme.of(context).colorScheme;
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25.0) return Colors.green;
    if (bmi < 30.0) return Colors.orange;
    return scheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _calculate();

    return Scaffold(
      appBar: AppBar(title: const Text('BMR Calculator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // About you
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About you', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 16),

                  // Sex
                  Row(
                    children: [
                      Text('Sex', style: theme.textTheme.bodyMedium),
                      const SizedBox(width: 24),
                      SegmentedButton<_Sex>(
                        segments: const [
                          ButtonSegment(value: _Sex.male, label: Text('Male')),
                          ButtonSegment(
                            value: _Sex.female,
                            label: Text('Female'),
                          ),
                        ],
                        selected: {_sex},
                        onSelectionChanged: (s) {
                          setState(() => _sex = s.first);
                          _savePrefs();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Age / Height / Weight
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ageCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Age',
                            suffix: Text('yrs'),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            setState(() {});
                            _savePrefs();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _heightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Height',
                            suffix: Text('cm'),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            setState(() {});
                            _savePrefs();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _weightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Weight',
                            suffix: Text('kg'),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            setState(() {});
                            _savePrefs();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Activity level
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Activity level', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  RadioGroup<_ActivityLevel>(
                    groupValue: _activity,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _activity = v);
                      _savePrefs();
                    },
                    child: Column(
                      children: _ActivityLevel.values
                          .map(
                            (level) => RadioListTile<_ActivityLevel>(
                              value: level,
                              title: Text(level.label),
                              subtitle: Text(
                                level.description,
                                style: theme.textTheme.bodySmall,
                              ),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Results
          if (result.bmi != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Results', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ResultTile(
                            label: 'BMI',
                            value: result.bmi!.toStringAsFixed(1),
                            sub: _bmiCategory(result.bmi!),
                            valueColor: _bmiColor(context, result.bmi!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ResultTile(
                            label: 'BMR',
                            value: '${result.bmr!.toStringAsFixed(0)} kcal',
                            sub: 'At complete rest',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ResultTile(
                            label: 'TDEE',
                            value: '${result.tdee!.toStringAsFixed(0)} kcal',
                            sub: 'Maintenance calories',
                            valueColor: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _BmiScale(bmi: result.bmi!),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          flex: _BmiScale.flexUnder,
                          child: Text(
                            'Under',
                            style: theme.textTheme.labelSmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: _BmiScale.flexNormal,
                          child: Text(
                            'Normal',
                            style: theme.textTheme.labelSmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: _BmiScale.flexOver,
                          child: Text(
                            'Over',
                            style: theme.textTheme.labelSmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: _BmiScale.flexObese,
                          child: Text(
                            'Obese',
                            style: theme.textTheme.labelSmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (_) {
                        final heightM =
                            (int.tryParse(_heightCtrl.text) ?? 0) / 100.0;
                        if (heightM <= 0) return const SizedBox.shrink();
                        final targetKg = 21.75 * heightM * heightM;
                        return Text(
                          'Mid-normal weight for your height: ${targetKg.toStringAsFixed(1)} kg',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'To lose ~0.5 kg/week subtract ~500 kcal from TDEE.\n'
                      'To gain ~0.5 kg/week add ~500 kcal.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () => _setGoal(
                              context,
                              result.tdee!.round() - 500,
                              'Cut',
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Cut',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${(result.tdee! - 500).toStringAsFixed(0)} kcal',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _setGoal(
                              context,
                              result.tdee!.round(),
                              'Maintain',
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Maintain',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${result.tdee!.toStringAsFixed(0)} kcal',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Fill in your age, height, and weight to see your BMR and TDEE.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'BMR calculated using the Mifflin–St Jeor equation. '
              'TDEE = BMR × activity multiplier.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _setGoal(BuildContext context, int kcal, String label) async {
    final provider = context.read<DiaryProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await provider.setDailyGoal(kcal);
    } catch (_) {}
    if (mounted) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('$label goal set to $kcal kcal')),
      );
    }
  }
}

// ── BMI scale bar ────────────────────────────────────────────────────────────

class _BmiScale extends StatelessWidget {
  final double bmi;
  const _BmiScale({required this.bmi});

  static const _min = 15.0;
  static const _max = 40.0;
  static const _underEnd = 18.5;
  static const _normalEnd = 25.0;
  static const _overEnd = 30.0;

  static const _underColor = Color(0xFF64B5F6);
  static const _normalColor = Color(0xFF66BB6A);
  static const _overColor = Color(0xFFFFA726);
  static const _obeseColor = Color(0xFFEF5350);

  static int _flexOf(double start, double end) =>
      ((end - start) / (_max - _min) * 100).round();

  static final flexUnder = _flexOf(_min, _underEnd);
  static final flexNormal = _flexOf(_underEnd, _normalEnd);
  static final flexOver = _flexOf(_normalEnd, _overEnd);
  static final flexObese = _flexOf(_overEnd, _max);

  int _flex(double start, double end) => _flexOf(start, end);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = ((bmi - _min) / (_max - _min)).clamp(0.0, 1.0);

    const boundaries = [_min, _underEnd, _normalEnd, _overEnd, _max];
    const barH = 28.0;
    const lw = 34.0;

    final numStyle = theme.textTheme.labelSmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.9),
      fontWeight: FontWeight.w600,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        double xOf(double v) =>
            ((v - _min) / (_max - _min)).clamp(0.0, 1.0) * w;
        final markerX = (t * w).clamp(1.5, w - 1.5);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Coloured sections ───────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Expanded(
                    flex: _flex(_min, _underEnd),
                    child: SizedBox(
                      height: barH,
                      child: const ColoredBox(color: _underColor),
                    ),
                  ),
                  Expanded(
                    flex: _flex(_underEnd, _normalEnd),
                    child: SizedBox(
                      height: barH,
                      child: const ColoredBox(color: _normalColor),
                    ),
                  ),
                  Expanded(
                    flex: _flex(_normalEnd, _overEnd),
                    child: SizedBox(
                      height: barH,
                      child: const ColoredBox(color: _overColor),
                    ),
                  ),
                  Expanded(
                    flex: _flex(_overEnd, _max),
                    child: SizedBox(
                      height: barH,
                      child: const ColoredBox(color: _obeseColor),
                    ),
                  ),
                ],
              ),
            ),

            // ── Boundary numbers inside the bar ─────────────────────────────
            for (int i = 0; i < boundaries.length; i++)
              Positioned(
                left: i == boundaries.length - 1
                    ? null
                    : (i == 0 ? 2 : xOf(boundaries[i]) - lw / 2),
                right: i == boundaries.length - 1 ? 2 : null,
                top: 0,
                bottom: 0,
                child: Center(
                  child: SizedBox(
                    width: lw,
                    child: Text(
                      boundaries[i] == boundaries[i].truncateToDouble()
                          ? boundaries[i].toStringAsFixed(0)
                          : boundaries[i].toStringAsFixed(1),
                      style: numStyle,
                      textAlign: i == 0
                          ? TextAlign.left
                          : i == boundaries.length - 1
                          ? TextAlign.right
                          : TextAlign.center,
                    ),
                  ),
                ),
              ),

            // ── Marker line ─────────────────────────────────────────────────
            Positioned(
              left: markerX - 1.5,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 2),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color? valueColor;

  const _ResultTile({
    required this.label,
    required this.value,
    required this.sub,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        Text(sub, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
