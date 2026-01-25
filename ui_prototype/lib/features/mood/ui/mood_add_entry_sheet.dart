import 'package:flutter/material.dart';
import '../models/mood_models.dart';

class MoodAddEntrySheet extends StatefulWidget {
  final DateTime day;
  final MoodEntry? existing;
  final MoodPalette palette;

  const MoodAddEntrySheet({
    super.key,
    required this.day,
    required this.existing,
    required this.palette,
  });

  static Future<MoodEntry?> open(
    BuildContext context, {
    required DateTime day,
    required MoodEntry? existing,
    required MoodPalette palette,
  }) async {
    return showModalBottomSheet<MoodEntry?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MoodAddEntrySheet(day: day, existing: existing, palette: palette),
    );
  }

  @override
  State<MoodAddEntrySheet> createState() => _MoodAddEntrySheetState();
}

class _MoodAddEntrySheetState extends State<MoodAddEntrySheet> {
  late MoodType selectedMood;
  double intensity = 3;
  final Set<String> tags = <String>{};

  final titleCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  static const _quickTags = <String>[
    "İş",
    "Okul",
    "Aile",
    "Sağlık",
    "Spor",
    "Stres",
    "Uyku",
    "Motivasyon",
    "Sosyal",
    "Yalnız",
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    selectedMood = e?.mood ?? MoodType.okay;
    intensity = (e?.intensity ?? 3).toDouble();
    tags.addAll(e?.tags ?? const []);
    titleCtrl.text = e?.title ?? "Bugün";
    noteCtrl.text = e?.note ?? "";
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final entry = MoodEntry(
      day: dateOnly(widget.day),
      mood: selectedMood,
      intensity: intensity.round().clamp(1, 5),
      tags: tags.toList(),
      title: titleCtrl.text.trim().isEmpty ? "Bugün" : titleCtrl.text.trim(),
      note: noteCtrl.text.trim(),
    );
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.98,
        builder: (context, scrollCtrl) {
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scrollCtrl,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "${widget.day.day}.${widget.day.month}.${widget.day.year} için kayıt",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),

                // Mood grid
                const Text("Ruh hali", style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: kMoodOptions.map((m) {
                    final isSel = m.type == selectedMood;
                    final c = palette.colorOf(m.type);
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => selectedMood = m.type),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSel ? c.withOpacity(0.18) : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isSel ? c.withOpacity(0.8) : Colors.transparent),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(m.emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(height: 6),
                            Text(
                              m.labelTr,
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // intensity slider
                const Text("Yoğunluk", style: TextStyle(fontWeight: FontWeight.w800)),
                Slider(
                  value: intensity,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: intensity.round().toString(),
                  onChanged: (v) => setState(() => intensity = v),
                ),

                const SizedBox(height: 10),

                // Tags
                const Text("Etiketler", style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickTags.map((t) {
                    final sel = tags.contains(t);
                    return FilterChip(
                      label: Text(t),
                      selected: sel,
                      onSelected: (v) => setState(() {
                        if (v) {
                          tags.add(t);
                        } else {
                          tags.remove(t);
                        }
                      }),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: "Başlık",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: "Not",
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        child: const Text("İptal"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        child: const Text("Kaydet"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
