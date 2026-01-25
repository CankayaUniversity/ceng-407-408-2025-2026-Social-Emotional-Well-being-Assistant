import 'package:flutter/material.dart';
import '../models/mood_models.dart';

class MoodThemeCard extends StatelessWidget {
  final MoodThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  const MoodThemeCard({
    super.key,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.6) : Colors.transparent,
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(blurRadius: 20, offset: Offset(0, 8), color: Color(0x14000000)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(palette.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ...palette.colors.take(5).map((c) {
                        return Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (selected) const Icon(Icons.check_circle),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
