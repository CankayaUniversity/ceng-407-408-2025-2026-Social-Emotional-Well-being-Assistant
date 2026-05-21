import 'package:flutter/material.dart';

import 'appointment_models.dart';

class AppointmentAddSheet extends StatefulWidget {
  final DateTime initialDay;

  const AppointmentAddSheet({
    super.key,
    required this.initialDay,
  });

  static Future<AppointmentEntry?> open(
    BuildContext context, {
    required DateTime initialDay,
  }) {
    return showModalBottomSheet<AppointmentEntry?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppointmentAddSheet(initialDay: initialDay),
    );
  }

  @override
  State<AppointmentAddSheet> createState() => _AppointmentAddSheetState();
}

class _AppointmentAddSheetState extends State<AppointmentAddSheet> {
  static const _departments = <String>[
    'Acil Tıp',
    'Ağız ve Diş Sağlığı',
    'Aile Hekimliği',
    'Alerji ve İmmünoloji',
    'Anestezi ve Reanimasyon',
    'Beyin ve Sinir Cerrahisi',
    'Çocuk Cerrahisi',
    'Çocuk Sağlığı ve Hastalıkları',
    'Dermatoloji',
    'Endokrinoloji ve Metabolizma',
    'Enfeksiyon Hastalıkları',
    'Fizik Tedavi ve Rehabilitasyon',
    'Gastroenteroloji',
    'Geriatri',
    'Genel Cerrahi',
    'Göğüs Hastalıkları',
    'Göz Hastalıkları',
    'Hematoloji',
    'Kadın Hastalıkları ve Doğum',
    'Kalp ve Damar Cerrahisi',
    'Kardiyoloji',
    'Kulak Burun Boğaz',
    'Nefroloji',
    'Nöroloji',
    'Nükleer Tıp',
    'Onkoloji',
    'Ortopedi ve Travmatoloji',
    'Patoloji',
    'Plastik, Rekonstrüktif ve Estetik Cerrahi',
    'Psikiyatri',
    'Radyoloji',
    'Romatoloji',
    'Tıbbi Genetik',
    'Tıbbi Mikrobiyoloji',
    'Üroloji',
    'Diğer',
  ];

  late DateTime selectedDay;
  late TimeOfDay selectedTime;
  String? selectedDepartment;

  final doctorCtrl = TextEditingController();
  final hospitalCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  String? doctorError;
  String? departmentError;
  String? hospitalError;

  @override
  void initState() {
    super.initState();
    selectedDay = dateOnly(widget.initialDay);
    selectedTime = TimeOfDay.now();
    selectedDepartment = _departments.first;
  }

  @override
  void dispose() {
    doctorCtrl.dispose();
    hospitalCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime(2022, 1, 1),
      lastDate: DateTime(2030, 12, 31),
    );
    if (picked == null) return;
    setState(() => selectedDay = dateOnly(picked));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked == null) return;
    setState(() => selectedTime = picked);
  }

  void _save() {
    final doctor = doctorCtrl.text.trim();
    final department = selectedDepartment?.trim() ?? '';
    final hospital = hospitalCtrl.text.trim();
    final note = noteCtrl.text.trim();

    setState(() {
      doctorError = doctor.isEmpty ? 'Doktor adı zorunludur.' : null;
      departmentError = department.isEmpty ? 'Bölüm seçimi zorunludur.' : null;
      hospitalError = hospital.isEmpty ? 'Hastane / Klinik zorunludur.' : null;
    });

    if (doctorError != null || departmentError != null || hospitalError != null) {
      return;
    }

    final entry = AppointmentEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      day: selectedDay,
      timeHHmm: timeToHHmm(selectedTime),
      doctorName: doctor,
      department: department,
      hospital: hospital,
      location: null,
      type: null,
      note: note.isEmpty ? null : note,
    );

    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF2B3A67);

    return Container(
      color: Colors.transparent,
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
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
                const Text('Randevu Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined, color: navy),
                        label: Text(
                          '${selectedDay.day}.${selectedDay.month}.${selectedDay.year}',
                          style: const TextStyle(color: navy, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule, color: navy),
                        label: Text(
                          selectedTime.format(context),
                          style: const TextStyle(color: navy, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: doctorCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Doktor adi',
                    border: OutlineInputBorder(),
                  ).copyWith(errorText: doctorError),
                  onChanged: (_) {
                    if (doctorError == null) return;
                    setState(() => doctorError = null);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDepartment,
                  decoration: const InputDecoration(
                    labelText: 'Bolum',
                    border: OutlineInputBorder(),
                  ).copyWith(errorText: departmentError),
                  items: _departments
                      .map((d) => DropdownMenuItem<String>(
                            value: d,
                            child: Text(d),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      selectedDepartment = v;
                      departmentError = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hospitalCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Hastane / Klinik',
                    border: OutlineInputBorder(),
                  ).copyWith(errorText: hospitalError),
                  onChanged: (_) {
                    if (hospitalError == null) return;
                    setState(() => hospitalError = null);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Not (opsiyonel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Randevuyu Kaydet'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

