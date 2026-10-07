import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../tracker/presentation/widgets/common.dart';
import '../../tracker/state/tracker_controller.dart';

enum OnboardingAction { today, attack, diary }

/// Two short screens shown after authentication, using the Design components.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    required this.onStepChanged,
    required this.onFinished,
    this.initialStep = 0,
    super.key,
  });

  final int initialStep;
  final Future<void> Function(int step) onStepChanged;
  final Future<void> Function(OnboardingAction action) onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late int _step;
  bool _busy = false;
  String? _error;
  OnboardingAction _action = OnboardingAction.diary;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep.clamp(0, 1);
  }

  Future<void> _perform(Future<void> Function() request) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await request();
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _goTo(int step) => _perform(() async {
        await widget.onStepChanged(step);
        if (mounted) setState(() => _step = step);
      });

  Future<void> _finish(OnboardingAction action) =>
      _perform(() => widget.onFinished(action));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy && _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy && _step == 1) _goTo(0);
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.bluePale,
                AppColors.background,
                AppColors.background
              ],
              stops: [0, 0.5, 1],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      if (_step == 1)
                        IconButton(
                          tooltip: 'Назад',
                          onPressed: _busy ? null : () => _goTo(0),
                          icon: const Icon(Icons.chevron_left_rounded),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.white),
                        ),
                      if (_step == 1) const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          label: 'Шаг ${_step + 1} из 2',
                          child: ExcludeSemantics(
                            child: Row(
                              children: [
                                for (var index = 0; index < 2; index++) ...[
                                  Expanded(
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: index <= _step
                                            ? AppColors.blue
                                            : AppColors.line,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  if (index == 0) const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text('${_step + 1} / 2',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                    children:
                        _step == 0 ? _welcome(context) : _firstAction(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      PrimaryActionButton(
                        label: _busy
                            ? 'Сохраняем…'
                            : _step == 0
                                ? 'Начать'
                                : _action == OnboardingAction.attack
                                    ? 'Записать приступ'
                                    : 'Отметить самочувствие',
                        onPressed: _busy
                            ? null
                            : () => _step == 0 ? _goTo(1) : _finish(_action),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _finish(OnboardingAction.today),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          foregroundColor: AppColors.muted,
                        ),
                        child:
                            Text(_step == 0 ? 'Позже' : 'Перейти на главную'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _welcome(BuildContext context) => [
        const _WelcomePreview(),
        const SizedBox(height: 28),
        Text('Начнём с вашего\nсамочувствия',
            style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 12),
        const Text(
          'Записывайте приступы и отмечайте, как прошёл день. '
          'Ваши наблюдения будут собраны в одном месте.',
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 24),
        const _Benefit(
            icon: Icons.add_rounded,
            title: 'Быстрая запись приступа',
            subtitle: 'Время, сила боли и симптомы'),
        const SizedBox(height: 16),
        const _Benefit(
            icon: Icons.water_drop_outlined,
            title: 'Дневник самочувствия',
            subtitle: 'Сон, вода и стресс — даже в дни без боли'),
        const SizedBox(height: 16),
        const _Benefit(
            icon: Icons.menu_book_outlined,
            title: 'История под рукой',
            subtitle: 'Возвращайтесь к записям и дополняйте их'),
      ];

  List<Widget> _firstAction(BuildContext context) => [
        const Text('ПЕРВАЯ ЗАПИСЬ',
            style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6)),
        const SizedBox(height: 14),
        Text('С чего начнём?',
            style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 12),
        const Text(
            'Выберите, что подходит вам сейчас. Остальное можно добавить позже.',
            style: TextStyle(color: AppColors.muted, height: 1.5)),
        const SizedBox(height: 28),
        _ActionCard(
          icon: Icons.bolt_outlined,
          title: 'Сейчас есть боль',
          subtitle:
              'Запишите приступ. Подробности можно дополнить, когда станет легче.',
          selected: _action == OnboardingAction.attack,
          onTap: _busy
              ? null
              : () => setState(() => _action = OnboardingAction.attack),
        ),
        const SizedBox(height: 16),
        _ActionCard(
          icon: Icons.spa_outlined,
          title: 'Отметить самочувствие',
          subtitle:
              'Расскажите о сне, воде и стрессе. Это полезно и в день без боли.',
          selected: _action == OnboardingAction.diary,
          onTap: _busy
              ? null
              : () => setState(() => _action = OnboardingAction.diary),
        ),
        const SizedBox(height: 24),
        const AppCard(
          color: AppColors.mint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Начнём с наблюдений',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text(
                  'Сейчас доступны дневник и история записей. Личный прогноз появится на следующем этапе.'),
            ],
          ),
        ),
      ];
}

class _WelcomePreview extends StatelessWidget {
  const _WelcomePreview();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AppCard(
        color: AppColors.blueSoft,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.wb_sunny_outlined, color: AppColors.blue, size: 24),
              SizedBox(width: 10),
              Expanded(
                  child: Text('ВАШ ДНЕВНИК',
                      style: TextStyle(
                          color: AppColors.blue,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.8))),
            ]),
            const SizedBox(height: 18),
            Text('Как вы сегодня?',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            const AppCard(
              padding: EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.favorite_border_rounded, color: AppColors.teal),
                SizedBox(width: 12),
                Expanded(
                    child: Text('Маленькая запись.\nБольше внимания к себе.',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, height: 1.45))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.blue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12, height: 1.4)),
              ])),
        ],
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.selected,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: selected ? AppColors.blue : AppColors.line, width: 1.5),
            borderRadius: BorderRadius.circular(22),
          ),
          child: AppCard(
            color: selected ? AppColors.bluePale : AppColors.card,
            onTap: onTap,
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: AppColors.blue, size: 28),
                const Spacer(),
                Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? AppColors.blue : AppColors.muted,
                    size: 22),
              ]),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(subtitle,
                  style: const TextStyle(color: AppColors.muted, height: 1.5)),
            ]),
          ),
        ),
      );
}
