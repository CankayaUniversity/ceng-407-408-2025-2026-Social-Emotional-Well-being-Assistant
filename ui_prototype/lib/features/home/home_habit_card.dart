import 'package:flutter/material.dart';

class HomeHabitCard extends StatelessWidget {
  final String title;
  final String emoji;
  final Color color;
  final bool done;
  final String? timeText;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const HomeHabitCard({
    super.key,
    required this.title,
    required this.emoji,
    required this.color,
    required this.done,
    required this.timeText,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final fg = _readableTextColor(color);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              blurRadius: 14,
              offset: Offset(0, 8),
              color: Color(0x1A000000),
            )
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // ✅ gerçek emoji (kare ikon yok)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.28),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.28),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : Icons.circle_outlined,
                    color: fg,
                    size: 18,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  "Günlük",
                  style: TextStyle(
                    color: fg.withOpacity(.85),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (timeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      timeText!,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color _readableTextColor(Color bg) {
  final l = (0.2126 * bg.red + 0.7152 * bg.green + 0.0722 * bg.blue) / 255.0;
  return l > 0.65 ? Colors.black87 : Colors.white;
}
