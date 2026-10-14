import 'package:flutter/material.dart';
import '../state/analytics_controller.dart';

class AnalyticsPage extends StatefulWidget {
  final AnalyticsController controller;

  const AnalyticsPage({super.key, required this.controller});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика приступов'),
      ),
      body: ValueListenableBuilder<AnalyticsState>(
        valueListenable: widget.controller,
        builder: (context, state, child) {
          return Column(
            children: [
              _buildPeriodSelector(state.selectedPeriod),
              const Divider(height: 1),
              Expanded(
                child: _buildBody(state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeriodSelector(String currentPeriod) {
    final periods = {
      'week': 'Неделя',
      'month': 'Месяц',
      'year': 'Год',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: SegmentedButton<String>(
        segments: periods.entries.map((entry) {
          return ButtonSegment<String>(
            value: entry.key,
            label: Text(entry.value),
          );
        }).toList(),
        selected: {currentPeriod},
        onSelectionChanged: (newSelection) {
          widget.controller.changePeriod(newSelection.first);
        },
      ),
    );
  }

  Widget _buildBody(AnalyticsState state) {
    switch (state.status) {
      case AnalyticsStatus.loading:
      case AnalyticsStatus.initial:
        return const Center(
          child: CircularProgressIndicator(),
        );

      case AnalyticsStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  state.errorMessage ?? 'Произошла ошибка',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => widget.controller.loadAnalytics(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                ),
              ],
            ),
          ),
        );

      case AnalyticsStatus.empty:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_available, size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'За выбранный период приступов не зафиксировано',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
        );

      case AnalyticsStatus.success:
        final data = state.data!;
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _StatCard(
              title: 'Всего приступов',
              value: '${data.totalAttacks}',
              icon: Icons.flash_on,
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            _StatCard(
              title: 'Средняя интенсивность',
              value: '${data.averageIntensity.toStringAsFixed(1)} / 10',
              icon: Icons.bar_chart,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            _StatCard(
              title: 'Средняя длительность',
              value: data.formattedDuration,
              icon: Icons.timer,
              color: Colors.blue,
            ),
          ],
        );
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(38),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}