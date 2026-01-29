import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/emergency_contact_store.dart';
import 'emergency_contact_sheet.dart';

class TrustedContactsSheet extends StatefulWidget {
  const TrustedContactsSheet({super.key});

  static Future<bool> open(BuildContext context) async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TrustedContactsSheet(),
    );
    return res ?? false;
  }

  @override
  State<TrustedContactsSheet> createState() => _TrustedContactsSheetState();
}

class _TrustedContactsSheetState extends State<TrustedContactsSheet> {
  bool changed = false;
  bool _loading = false;

  List<EmergencyContact> get contacts => EmergencyContactStore.instance.contacts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await EmergencyContactStore.instance.load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Trusted contacts alınamadı: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final c = await EmergencyContactSheet.open(context);
    if (c == null) return;

    try {
      setState(() => _loading = true);
      await EmergencyContactStore.instance.add(c);
      changed = true;
      await EmergencyContactStore.instance.load();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kişi eklenemedi: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(int index) async {
    final existing = contacts[index];
    final c = await EmergencyContactSheet.open(context, existing: existing);
    if (c == null) return;

    try {
      setState(() => _loading = true);
      await EmergencyContactStore.instance.updateAt(index, c);
      changed = true;
      await EmergencyContactStore.instance.load();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kişi güncellenemedi: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Kişi silinsin mi?"),
        content: Text("${contacts[index].fullName} kaldırılacak."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Sil")),
        ],
      ),
    );

    if (ok != true) return;

    try {
      setState(() => _loading = true);
      await EmergencyContactStore.instance.removeAt(index);
      changed = true;
      await EmergencyContactStore.instance.load();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kişi silinemedi: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sms(EmergencyContact c) async {
    final phone = c.phone.trim();
    final body = Uri.encodeComponent(
      "Merhaba ${c.fullName}, acil bir durumda sana ulaşmam gerekiyor. Müsait misin?",
    );

    final uri = Uri.parse("sms:$phone?body=$body");
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("SMS uygulaması bulunamadı.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = MediaQuery.of(context).size.height;

    return Container(
      height: h * 0.85,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  "Trusted Contacts",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context, changed),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : contacts.isEmpty
                  ? Center(
                child: Text(
                  "Henüz kişi yok.\nSağ alttaki + ile ekleyebilirsin.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
                  : ListView.separated(
                itemCount: contacts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final c = contacts[i];
                  return Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.contact_phone_rounded),
                      title: Text(
                        "${c.fullName} (${c.relation})",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        "Tel: ${c.phone}",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            tooltip: "SMS",
                            onPressed: () => _sms(c),
                            icon: const Icon(Icons.sms_outlined),
                          ),
                          IconButton(
                            tooltip: "Düzenle",
                            onPressed: () => _edit(i),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            tooltip: "Sil",
                            onPressed: () => _delete(i),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _add,
                icon: const Icon(Icons.add),
                label: const Text("Kişi Ekle"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
