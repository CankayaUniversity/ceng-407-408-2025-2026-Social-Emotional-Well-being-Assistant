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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((o) {
          final isSel = o.type == selected;
          final c = palette.colorOf(o.type);

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelect(o.type),
              child: Container(
                width: 130,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSel ? c.withOpacity(0.18) : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSel ? c.withOpacity(0.75) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(o.emoji, style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        o.labelTr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
