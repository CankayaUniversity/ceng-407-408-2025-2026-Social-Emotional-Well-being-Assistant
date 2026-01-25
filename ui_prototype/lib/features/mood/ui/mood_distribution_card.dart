import 'package:flutter/material.dart';
import '../models/mood_models.dart';

class MoodDistributionCard extends StatelessWidget {
  final Map<MoodType, int> counts;
  final MoodPalette palette;

  const MoodDistributionCard({
    super.key,
    required this.counts,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final ordered = kMoodOptions.map((o) => counts[o.type] ?? 0).toList();
    final total = ordered.fold<int>(0, (a, b) => a + b);
    int pct(int v) => total == 0 ? 0 : ((v / total) * 100).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(blurRadius: 20, offset: Offset(0, 8), color: Color(0x14000000)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Bu Ay Dağılım",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...List.generate(kMoodOptions.length, (i) {
            final o = kMoodOptions[i];
            final v = ordered[i];
            final c = palette.colorOf(o.type);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(o.labelTr, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text("%${pct(v)}"),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
