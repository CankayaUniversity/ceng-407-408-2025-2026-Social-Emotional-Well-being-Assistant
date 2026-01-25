import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'medicine_models.dart';

class MedicineScreen extends StatefulWidget {
  final DateTime day;
  const MedicineScreen({super.key, required this.day});

  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  final List<MedicinePlan> _plans = [];

  bool get _allTakenToday {
    if (_plans.isEmpty) return false;
    for (final p in _plans) {
      if (p.doses.isEmpty) return false;
      if (p.doses.any((d) => d.taken == false)) return false;
    }
    return true;
  }

  Future<bool> _onWillPop() async {
    Navigator.pop(context, _allTakenToday);
    return false;
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _hhmm(TimeOfDay t) => "${_two(t.hour)}:${_two(t.minute)}";

  Future<void> _addMedicine() async {
    final plan = await showModalBottomSheet<MedicinePlan>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMedicineSheet(formatTime: _hhmm),
    );

    if (!mounted) return;
    if (plan == null) return;

    setState(() => _plans.add(plan));
  }

  @override
  Widget build(BuildContext context) {
    final dayText = DateFormat("d MMMM, EEEE", "tr_TR").format(widget.day);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Takviye / İlaç"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _allTakenToday),
          ),
          actions: [
            IconButton(
              tooltip: "İlaç ekle",
              onPressed: _addMedicine,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dayText,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),

              if (_allTakenToday)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F7EF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFE7CF)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_rounded, color: Color(0xFF2E7D32)),
                      SizedBox(width: 8),
                      Text(
                        "TAMAMLANDI",
                        style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2E7D32)),
                      ),
                    ],
                  ),
                ),

              if (_allTakenToday) const SizedBox(height: 10),

              if (_plans.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.03),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Text(
                    "Bugün için ilaç yok. Sağ üstten + ile ekle.",
                    style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _plans.length,
                    itemBuilder: (context, index) {
                      final med = _plans[index];
                      final takenCount = med.doses.where((d) => d.taken).length;
                      final total = med.doses.length;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.03),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text("💊", style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    med.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(
                                  "$takenCount/$total",
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            for (int i = 0; i < med.doses.length; i++)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: CheckboxListTile(
                                  dense: true,
                                  value: med.doses[i].taken,
                                  onChanged: (v) {
                                    setState(() => med.doses[i].taken = v ?? false);
                                  },
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: Text(
                                    "Vakit: ${med.doses[i].timeHHmm}",
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  subtitle: Text(
                                    "Doz ${i + 1}",
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => setState(() => _plans.removeAt(index)),
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text("Sil"),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================
   Add Medicine Sheet (Result döner)
   ============================ */

class _AddMedicineSheet extends StatefulWidget {
  final String Function(TimeOfDay) formatTime;
  const _AddMedicineSheet({required this.formatTime});

  @override
  State<_AddMedicineSheet> createState() => _AddMedicineSheetState();
}

class _AddMedicineSheetState extends State<_AddMedicineSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  int _timesPerDay = 1;
  final List<TimeOfDay?> _times = [null];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _syncTimes() {
    if (_times.length < _timesPerDay) {
      _times.addAll(List.generate(_timesPerDay - _times.length, (_) => null));
    } else if (_times.length > _timesPerDay) {
      _times.removeRange(_timesPerDay, _times.length);
    }
  }

  Future<void> _pick(int i) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[i] ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() => _times[i] = picked);
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("İlaç adı boş olamaz.")),
      );
      return;
    }
    if (_times.any((t) => t == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen tüm vakitleri seç.")),
      );
      return;
    }

    final times = _times.map((t) => widget.formatTime(t!)).toList()..sort();

    final plan = MedicinePlan(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      doses: times.map((hhmm) => MedicineDose(timeHHmm: hhmm)).toList(),
    );

    Navigator.pop(context, plan);
  }

  @override
  Widget build(BuildContext context) {
    _syncTimes();
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 12, right: 12, bottom: bottom + 12, top: 12),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                blurRadius: 24,
                offset: Offset(0, 12),
                color: Color(0x22000000),
              )
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text("İlaç ekle",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: "İlaç adı",
                      prefixText: "💊 ",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Expanded(
                        child: Text("Günde kaç kere?",
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.04),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: DropdownButton<int>(
                          value: _timesPerDay,
                          underline: const SizedBox.shrink(),
                          items: List.generate(8, (i) => i + 1)
                              .map((v) => DropdownMenuItem(value: v, child: Text("$v")))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _timesPerDay = v);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Vakitler", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 8),

                  for (int i = 0; i < _timesPerDay; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.schedule_rounded),
                        title: Text("Doz ${i + 1}",
                            style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(
                          _times[i] == null ? "Saat seç" : widget.formatTime(_times[i]!),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _pick(i),
                      ),
                    ),

                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text("Ekle"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
