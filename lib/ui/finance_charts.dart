import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'formatters.dart';

class ExpenseBarChart extends StatelessWidget {
  const ExpenseBarChart({super.key, required this.grouped});

  final Map<String, double> grouped;

  @override
  Widget build(BuildContext context) {
    final maxValue = grouped.values.fold(
      0.0,
      (max, value) => value > max ? value : max,
    );
    return Column(
      children: grouped.entries.map((entry) {
        final ratio = maxValue == 0 ? 0.0 : entry.value / maxValue;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: ratio, minHeight: 12),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 76,
                child: Text(currency(entry.value), textAlign: TextAlign.end),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class ExpensePieChart extends StatelessWidget {
  const ExpensePieChart({super.key, required this.grouped});

  final Map<String, double> grouped;

  @override
  Widget build(BuildContext context) {
    final total = grouped.values.fold(0.0, (sum, value) => sum + value);
    final sorted = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.donut_large_outlined),
            const SizedBox(width: 8),
            const Expanded(child: Text('其他')),
            Text(
              currency(total),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final entry in sorted)
          ExpenseCategoryRingRow(
            label: entry.key,
            amount: entry.value,
            ratio: total == 0 ? 0 : entry.value / total,
          ),
      ],
    );
  }
}

class IncomeAccountBarChart extends StatelessWidget {
  const IncomeAccountBarChart({super.key, required this.grouped});

  final Map<String, double> grouped;

  @override
  Widget build(BuildContext context) {
    final sorted = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxAmount = sorted.isEmpty ? 0.0 : sorted.first.value;
    final total = grouped.values.fold(0.0, (sum, value) => sum + value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bar_chart),
            const SizedBox(width: 8),
            const Expanded(child: Text('本月收入')),
            Text(
              currency(total),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final entry in sorted)
          IncomeAccountBarRow(
            label: entry.key,
            amount: entry.value,
            ratio: maxAmount <= 0 ? 0 : entry.value / maxAmount,
          ),
      ],
    );
  }
}

class IncomeAccountBarRow extends StatelessWidget {
  const IncomeAccountBarRow({
    super.key,
    required this.label,
    required this.amount,
    required this.ratio,
  });

  final String label;
  final double amount;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor('收入$label');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Text(currency(amount)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 16, color: const Color(0xffe8eee9)),
                FractionallySizedBox(
                  widthFactor: ratio.clamp(0.04, 1.0),
                  child: Container(height: 16, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseCategoryRingRow extends StatelessWidget {
  const ExpenseCategoryRingRow({
    super.key,
    required this.label,
    required this.amount,
    required this.ratio,
  });

  final String label;
  final double amount;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: CustomPaint(
              painter: ExpenseRingPainter(
                color: categoryColor(label),
                ratio: ratio.clamp(0.0, 1.0),
              ),
              child: Center(
                child: Text(
                  '${(ratio * 100).round()}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Text(currency(amount)),
        ],
      ),
    );
  }
}

class ExpenseRingPainter extends CustomPainter {
  ExpenseRingPainter({required this.color, required this.ratio});

  final Color color;
  final double ratio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 7;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xffe6ebe6);
    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.butt
      ..color = color;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(rect, -math.pi / 2, ratio * math.pi * 2, false, valuePaint);
  }

  @override
  bool shouldRepaint(covariant ExpenseRingPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.ratio != ratio;
  }
}

class CategoryDot extends StatelessWidget {
  const CategoryDot({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(radius: 12, backgroundColor: categoryColor(label));
  }
}

Color categoryColor(String label) {
  if (label.contains('食物')) return const Color(0xffe53935);
  if (label.contains('交通')) return const Color(0xffff9800);
  if (label.contains('娛樂')) return const Color(0xff8e24aa);
  if (label.contains('訂閱')) return const Color(0xff00897b);
  if (label.contains('學習')) return const Color(0xff3949ab);
  if (label.contains('收入')) return const Color(0xff43a047);
  const colors = [
    Color(0xffd81b60),
    Color(0xff1e88e5),
    Color(0xffffb300),
    Color(0xff6d4c41),
    Color(0xff00acc1),
    Color(0xff7cb342),
  ];
  return colors[label.hashCode.abs() % colors.length];
}
