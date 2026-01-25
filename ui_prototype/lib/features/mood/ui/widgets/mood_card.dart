import 'package:flutter/material.dart';

class MoodCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const MoodCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      // ✅ eski davranış: margin yok
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // ✅ en kritik fix: artık beyaz değil, theme surface
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),

        // ✅ dark modda çok hafif border okunurluğu artırır
        border: Border.all(
          color: cs.outline.withOpacity(isDark ? 0.35 : 0.18),
          width: 1,
        ),

        boxShadow: [
          BoxShadow(
            // ✅ dark/light için farklı gölge
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    // ✅ yazı rengi artık theme’den
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (trailing != null)
                IconTheme.merge(
                  data: IconThemeData(color: cs.onSurface.withOpacity(0.85)),
                  child: trailing!,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ✅ Kart içindeki metin/iconlar da theme’e uysun
          DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface),
            child: IconTheme.merge(
              data: IconThemeData(color: cs.onSurface.withOpacity(0.85)),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
