import 'package:flutter/material.dart';
import '../models/mood_models.dart';

class MoodQuickSelector extends StatelessWidget {
  final List<MoodOption> options;
  final MoodType? selected;
  final MoodPalette palette;
  final ValueChanged<MoodType> onSelect;

  const MoodQuickSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.palette,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF2B3A67);
    const mint = Color(0xFFD6E5E3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Nasılsın?",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: navy,
              ),
            ),
            Text(
              "BUGÜN",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: navy.withOpacity(0.4),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((o) {
              final isSel = o.type == selected;
              final c = palette.colorOf(o.type);

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => onSelect(o.type),
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isSel ? mint : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSel ? navy.withOpacity(0.2) : navy.withOpacity(0.05),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: navy.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          o.emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        o.labelTr.toLowerCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                          color: isSel ? navy : navy.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
