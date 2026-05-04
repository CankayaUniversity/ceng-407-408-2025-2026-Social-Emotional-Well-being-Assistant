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
    const navy = Color(0xFF2B3A67);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: navy.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 4),
              color: navy.withOpacity(0.05),
            )
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Small colored emoji box
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const Spacer(),
                // Circle checkmark
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: done ? color.withOpacity(0.2) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: done ? color : navy.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: done
                      ? Icon(Icons.check_rounded, color: color, size: 16)
                      : null,
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: navy,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              done ? "Tamamlandı" : (timeText ?? "Devam ediyor"),
              style: TextStyle(
                color: done ? color.withOpacity(0.7) : navy.withOpacity(0.4),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
