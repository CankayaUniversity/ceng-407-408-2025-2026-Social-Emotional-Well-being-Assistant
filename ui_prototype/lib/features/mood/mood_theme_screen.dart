import 'package:flutter/material.dart';
import 'data/mood_repository.dart';
import 'models/mood_models.dart';
import 'ui/mood_theme_card.dart';

class MoodThemeScreen extends StatelessWidget {
  final MoodRepository repo;

  const MoodThemeScreen({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Ruh Hali Özelleştirme")),
      body: AnimatedBuilder(
        animation: repo,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                "Renk Teması",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Ruh hali kategorileriniz için bir renk paleti seçin.",
                style: TextStyle(color: cs.onSurface.withOpacity(0.70)),
              ),
              const SizedBox(height: 14),
              ...kThemePalettes.map((p) {
                final selected = repo.palette.name == p.name;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MoodThemeCard(
                    palette: p,
                    selected: selected,
                    onTap: () => repo.setPalette(p.palette),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
