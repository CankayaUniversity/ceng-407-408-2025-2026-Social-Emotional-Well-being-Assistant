import 'package:flutter/material.dart';
import '../data/emergency_contact_store.dart';

class EmergencyContactSheet extends StatefulWidget {
  final EmergencyContact? existing;
  const EmergencyContactSheet({super.key, this.existing});

  static Future<EmergencyContact?> open(
      BuildContext context, {
        EmergencyContact? existing,
      }) {
    return showModalBottomSheet<EmergencyContact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EmergencyContactSheet(existing: existing),
    );
  }

  @override
  State<EmergencyContactSheet> createState() => _EmergencyContactSheetState();
}

class _EmergencyContactSheetState extends State<EmergencyContactSheet> {
  late final TextEditingController firstName;
  late final TextEditingController lastName;
  late final TextEditingController phone;

  String relation = "Arkadaş";
  bool isPrimary = true;

  final relations = const [
    "Arkadaş",
    "Akraba",
    "Anne",
    "Baba",
    "Abi",
    "Abla",
    "Eş",
    "Partner",
    "Diğer",
  ];

  @override
  void initState() {
    super.initState();
    firstName = TextEditingController(text: widget.existing?.firstName ?? "");
    lastName = TextEditingController(text: widget.existing?.lastName ?? "");
    phone = TextEditingController(text: widget.existing?.phone ?? "");
    relation = widget.existing?.relation ?? relation;

    // ✅ primary bilgisi (backend modelinde var)
    isPrimary = widget.existing?.isPrimary ?? true;
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    super.dispose();
  }

  void _save() {
    final fn = firstName.text.trim();
    final ln = lastName.text.trim();
    final ph = phone.text.trim();

    if (fn.isEmpty || ln.isEmpty || ph.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen isim, soyisim ve telefon gir.")),
      );
      return;
    }

    // ✅ Edit ise id’yi kaybetmemek için existing.id’yi koruyoruz
    Navigator.pop(
      context,
      EmergencyContact(
        id: widget.existing?.id,
        firstName: fn,
        lastName: ln,
        relation: relation,
        phone: ph,
        isPrimary: isPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottom),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                Text(
                  widget.existing == null ? "Yakın Kişi Ekle" : "Yakın Kişi Düzenle",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: firstName,
              decoration: const InputDecoration(labelText: "İsim"),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lastName,
              decoration: const InputDecoration(labelText: "Soyisim"),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: relation,
              items: relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => relation = v ?? relation),
              decoration: const InputDecoration(labelText: "Yakınlık Derecesi"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              decoration: const InputDecoration(
                labelText: "Telefon Numarası",
                hintText: "05xx... veya +90...",
              ),
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 10),

            // ✅ Primary seçimi (isterseniz kaldırabilirsiniz)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: isPrimary,
              onChanged: (v) => setState(() => isPrimary = v),
              title: const Text("Birincil kişi (Primary)"),
              subtitle: const Text("Crisis help ekranında ilk bu kişi kullanılır."),
            ),

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text("Kaydet"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
