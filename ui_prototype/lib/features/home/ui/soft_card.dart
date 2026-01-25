import 'package:flutter/material.dart';

class SoftCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const SoftCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // ✅ Dark/Light uyumlu arka plan ve border (hard-code renk yok)
    final bg = isDark ? cs.surfaceContainerHigh : cs.surfaceContainerHighest;
    final borderColor = cs.outlineVariant.withOpacity(isDark ? 0.55 : 0.75);

    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w900,
      color: cs.onSurface,
    );

    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: cs.onSurfaceVariant,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.08),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: titleStyle),
                const SizedBox(height: 4),
                Text(subtitle, style: subtitleStyle),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}
