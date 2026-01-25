import 'package:flutter/material.dart';
import '../models/mood_models.dart';

class MoodJournalCard extends StatelessWidget {
  final MoodEntry? entry;
  final MoodPalette palette;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MoodJournalCard({
    super.key,
    required this.entry,
    required this.palette,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (entry == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(blurRadius: 20, offset: Offset(0, 8), color: Color(0x14000000)),
          ],
        ),
        child: Row(
          children: const [
            Icon(Icons.note_add_outlined),
            SizedBox(width: 10),
            Expanded(child: Text("Seçili gün için kayıt yok. + ile ekleyebilirsin.")),
          ],
        ),
      );
    }

    final opt = optionOf(entry!.mood);
    final c = palette.colorOf(entry!.mood);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withOpacity(0.35)),
        boxShadow: const [
          BoxShadow(blurRadius: 20, offset: Offset(0, 8), color: Color(0x14000000)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(opt.emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry!.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      "${opt.labelTr} • Yoğunluk ${entry!.intensity}/5",
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: "Düzenle",
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: "Sil",
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (entry!.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entry!.tags.map((t) => _MoodChip(text: t)).toList(),
            ),
          ],
          if (entry!.note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              entry!.note,
              style: TextStyle(height: 1.25, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85)),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  final String text;

  const _MoodChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
