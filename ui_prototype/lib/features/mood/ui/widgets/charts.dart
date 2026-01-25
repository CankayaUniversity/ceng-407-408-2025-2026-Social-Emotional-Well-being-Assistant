import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/mood_palette.dart';

class DonutChart extends StatelessWidget {
  final Map<int, int> distribution; // 1..5 -> count
  final int total;
  const DonutChart({super.key, required this.distribution, required this.total});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: CustomPaint(
              painter: _DonutPainter(distribution: distribution, total: total),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "$total",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    const Text("Kayıt", style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [5, 4, 3, 2, 1].map((m) {
                final c = distribution[m] ?? 0;
                final pct = total == 0 ? 0 : (c * 100 / total).round();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(MoodPalette.emojiOf(m), style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : c / total,
                            minHeight: 10,
                            backgroundColor: const Color(0xFFECEFF3),
                            valueColor: AlwaysStoppedAnimation(MoodPalette.colorOf(m)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text("%$pct", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final Map<int, int> distribution;
  final int total;

  _DonutPainter({required this.distribution, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2.2;
    final stroke = radius * 0.35;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // background ring
    paint.color = const Color(0xFFECEFF3);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      pi * 2,
      false,
      paint,
    );

    if (total <= 0) return;

    double start = -pi / 2;
    for (final mood in [1, 2, 3, 4, 5]) {
      final count = distribution[mood] ?? 0;
      if (count == 0) continue;
      final sweep = (count / total) * (pi * 2);

      paint.color = MoodPalette.colorOf(mood);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Haftalık bar: 7 değer (0..5)
class BarChartWeek extends StatelessWidget {
  final List<double> values; // len=7
  final List<String> labels; // len=7
  const BarChartWeek({super.key, required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: CustomPaint(
        painter: _BarPainter(values: values, labels: labels),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;

  _BarPainter({required this.values, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = 5.0;
    final padding = 22.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    final barW = w / (values.length * 1.7);
    final gap = (w - barW * values.length) / (values.length - 1);

    final bg = Paint()..color = const Color(0xFFF6F7F9);
    final labelStyle = const TextStyle(fontSize: 10, color: Colors.black54);

    // baseline
    final baseY = padding + h;
    final line = Paint()
      ..color = const Color(0xFFE2E6EC)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(padding, baseY), Offset(padding + w, baseY), line);

    for (int i = 0; i < values.length; i++) {
      final v = values[i].clamp(0, 5);
      final barH = (v / maxV) * h;
      final x = padding + i * (barW + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, baseY - barH, barW, barH),
        const Radius.circular(10),
      );

      // mood-based color: 0 ise gri
      final mood = v == 0 ? 0 : v.round().clamp(1, 5);
      final color = mood == 0 ? const Color(0xFFD5DAE2) : MoodPalette.colorOf(mood);

      final paint = Paint()..color = color;
      canvas.drawRRect(rect, paint);

      // label
      _text(canvas, labels[i], Offset(x + barW / 2, baseY + 8), labelStyle, center: true);
    }
  }

  void _text(Canvas canvas, String text, Offset pos, TextStyle style, {bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final offset = center ? Offset(pos.dx - tp.width / 2, pos.dy) : pos;
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Son 7 gün trend line (0..5)
class LineChartTrend extends StatelessWidget {
  final List<double> values; // len=7
  final List<String> labels; // len=7
  const LineChartTrend({super.key, required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: CustomPaint(
        painter: _LinePainter(values: values, labels: labels),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;

  _LinePainter({required this.values, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 22.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    final bg = Paint()..color = const Color(0xFFF6F7F9);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(padding, padding, w, h),
      const Radius.circular(16),
    );
    canvas.drawRRect(rect, bg);

    // grid lines
    final grid = Paint()
      ..color = const Color(0xFFE2E6EC)
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      final y = padding + (h / 5) * i;
      canvas.drawLine(Offset(padding, y), Offset(padding + w, y), grid);
    }

    // points
    Offset pt(int i, double v) {
      final x = padding + (w / (values.length - 1)) * i;
      final y = padding + h - (v.clamp(0, 5) / 5.0) * h;
      return Offset(x, y);
    }

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final p = pt(i, values[i]);
      if (i == 0) path.moveTo(p.dx, p.dy);
      else path.lineTo(p.dx, p.dy);
    }

    // line + fill
    final linePaint = Paint()
      ..color = MoodPalette.colorOf(5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = MoodPalette.colorOf(5).withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final fillPath = Path.from(path)
      ..lineTo(padding + w, padding + h)
      ..lineTo(padding, padding + h)
      ..close();

    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, linePaint);

    // dots
    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      final mood = v == 0 ? 0 : v.round().clamp(1, 5);
      final c = mood == 0 ? const Color(0xFFD5DAE2) : MoodPalette.colorOf(mood);
      final p = pt(i, v);

      canvas.drawCircle(p, 5.2, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4.2, Paint()..color = c);
    }

    // x labels
    const labelStyle = TextStyle(fontSize: 10, color: Colors.black54);
    for (int i = 0; i < labels.length; i++) {
      final x = padding + (w / (labels.length - 1)) * i;
      _text(canvas, labels[i], Offset(x, padding + h + 8), labelStyle, center: true);
    }
  }

  void _text(Canvas canvas, String text, Offset pos, TextStyle style, {bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final offset = center ? Offset(pos.dx - tp.width / 2, pos.dy) : pos;
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Takvim Heatmap: son 30 gün için (gün kutuları)
class CalendarHeatmap extends StatelessWidget {
  final Map<DateTime, int> dayMood; // date->mood(1..5) , yoksa 0
  final int days; // örn 30
  const CalendarHeatmap({super.key, required this.dayMood, this.days = 30});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: CustomPaint(
        painter: _HeatPainter(dayMood: dayMood, days: days),
      ),
    );
  }
}

class _HeatPainter extends CustomPainter {
  final Map<DateTime, int> dayMood;
  final int days;

  _HeatPainter({required this.dayMood, required this.days});

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 10.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    // 7 sütun (Pzt..Paz), satır sayısı days/7
    const cols = 7;
    final rows = (days / cols).ceil();

    final cell = min(w / cols, h / rows);
    final startX = padding + (w - cell * cols) / 2;
    final startY = padding + (h - cell * rows) / 2;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Paint border = Paint()
      ..color = const Color(0xFFE2E6EC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < days; i++) {
      final d = today.subtract(Duration(days: (days - 1 - i))); // eski -> yeni
      final key = DateTime(d.year, d.month, d.day);

      // haftanın günü: Mon=1..Sun=7 → col = weekday-1
      final col = key.weekday - 1;
      final row = (i / cols).floor();

      final x = startX + col * cell;
      final y = startY + row * cell;

      final mood = dayMood[key] ?? 0;
      final fill = Paint()
        ..color = mood == 0 ? const Color(0xFFF1F3F6) : MoodPalette.colorOf(mood).withOpacity(0.85);

      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 3, y + 3, cell - 6, cell - 6),
        const Radius.circular(6),
      );

      canvas.drawRRect(r, fill);
      canvas.drawRRect(r, border);
    }

    // küçük legend
    const labelStyle = TextStyle(fontSize: 10, color: Colors.black54);
    _text(canvas, "30 Gün", Offset(padding, 2), labelStyle);
    _text(canvas, "😡", Offset(size.width - padding - 70, 2), labelStyle);
    _text(canvas, "→", Offset(size.width - padding - 52, 2), labelStyle);
    _text(canvas, "😊", Offset(size.width - padding - 35, 2), labelStyle);
  }

  void _text(Canvas canvas, String text, Offset pos, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
