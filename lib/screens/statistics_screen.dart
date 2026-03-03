import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/dummy_data.dart';
import '../theme/app_colors.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  int _periodIndex = 0; // 0=Week, 1=Month, 2=Year

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? darkCard : lightCard;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Period selector
          Row(
            children: ['Week', 'Month', 'Year'].asMap().entries.map((e) {
              final active = _periodIndex == e.key;
              return GestureDetector(
                onTap: () => setState(() => _periodIndex = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: e.key < 2 ? 10 : 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Summary Row
          _buildSummaryRow(context, card),
          const SizedBox(height: 24),

          // Bar Chart
          _buildBarChart(context, card),
          const SizedBox(height: 24),

          // Category breakdown
          _buildCategoryBreakdown(context, card),
          const SizedBox(height: 24),

          // Streak
          _buildStreak(context, card),
          const SizedBox(height: 24),

          // Heatmap
          _buildHeatmap(context, card),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, Color card) {
    final items = [
      {'value': '85%', 'label': 'Completion', 'color': statusCompleted},
      {
        'value': '24',
        'label': 'Done',
        'color': Theme.of(context).colorScheme.primary
      },
      {'value': '3', 'label': 'Overdue', 'color': statusOverdue},
    ];

    return Row(
      children: items.asMap().entries.map((e) {
        final item = e.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: e.key < 2 ? 10 : 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: (item['color'] as Color).withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  item['value'] as String,
                  style: GoogleFonts.nunito(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: item['color'] as Color,
                  ),
                ),
                Text(
                  item['label'] as String,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBarChart(BuildContext context, Color card) {
    final primary = Theme.of(context).colorScheme.primary;
    final textSecondary = Theme.of(context).textTheme.bodyMedium?.color;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 18, color: primary),
              const SizedBox(width: 8),
              Text(
                'Completion Rate This Week',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...weeklyStats.map((stat) {
            final pct = stat['percent'] as double;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      stat['day'] as String,
                      style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 14,
                        backgroundColor: primary.withValues(alpha: 0.12),
                        color: pct == 0
                            ? primary.withValues(alpha: 0.2)
                            : pct < 0.5
                                ? statusRisk
                                : pct < 0.8
                                    ? primary.withValues(alpha: 0.7)
                                    : statusCompleted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${(pct * 100).round()}%',
                      style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(BuildContext context, Color card) {
    final textSecondary = Theme.of(context).textTheme.bodyMedium?.color;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.donut_large_rounded,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Top Categories',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...categoryStats.map((stat) {
            final pct = stat['percent'] as double;
            final color = stat['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 70,
                    child: Text(
                      stat['label'] as String,
                      style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 12,
                        backgroundColor: color.withValues(alpha: 0.12),
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(pct * 100).round()}%',
                    style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStreak(BuildContext context, Color card) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      'Current Streak',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '5 Days',
                  style: GoogleFonts.nunito(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: statusRisk,
                  ),
                ),
              ],
            ),
          ),
          Container(
              width: 1, height: 60, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Best Streak',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '12 Days',
                  style: GoogleFonts.nunito(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmap(BuildContext context, Color card) {
    const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final primary = Theme.of(context).colorScheme.primary;
    final textSecondary = Theme.of(context).textTheme.bodyMedium?.color;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view_rounded, size: 18, color: primary),
              const SizedBox(width: 8),
              Text(
                'Activity  — Last 4 Weeks',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Day labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: dayLabels
                .map((d) => SizedBox(
                      width: 28,
                      child: Text(d,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Grid
          ...heatmapData.map((week) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: week.map((activity) {
                    final opacity = activity == 0
                        ? 0.07
                        : activity == 1
                            ? 0.3
                            : activity == 2
                                ? 0.6
                                : 0.9;
                    return Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: activity == 0
                            ? primary.withValues(alpha: 0.07)
                            : primary.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    );
                  }).toList(),
                ),
              )),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Less',
                  style: TextStyle(color: textSecondary, fontSize: 11)),
              const SizedBox(width: 6),
              ...List.generate(
                4,
                (i) => Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: [0.07, 0.3, 0.6, 0.9][i]),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Text('More',
                  style: TextStyle(color: textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
