import 'package:flutter/material.dart';

class WaterScreen extends StatefulWidget {
  final DateTime day;
  const WaterScreen({super.key, required this.day});

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  final _kgCtrl = TextEditingController();
  double? _dailyLiters;
  bool _doneToday = false;

  @override
  void dispose() {
    _kgCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final raw = _kgCtrl.text.trim().replaceAll(',', '.');
    final kg = double.tryParse(raw);

    if (kg == null || kg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen geçerli bir kilo gir.")),
      );
      return;
    }

    setState(() {
      _dailyLiters = kg * 0.033;
      _doneToday = false;
    });
  }

  Future<bool> _onWillPop() async {
    Navigator.pop(context, _doneToday);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final resultText =
    _dailyLiters == null ? "—" : "${_dailyLiters!.toStringAsFixed(2)} L";

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Su İç"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _doneToday),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Günlük su ihtiyacı hesapla",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _kgCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Kilon (kg)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _calculate,
                  child: const Text("Hesapla"),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.03),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Sonuç", style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(
                      resultText,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: _doneToday,
                          onChanged: (_dailyLiters == null)
                              ? null
                              : (v) => setState(() => _doneToday = v ?? false),
                        ),
                        Expanded(
                          child: Text(
                            _dailyLiters == null
                                ? "Önce hesapla"
                                : "Bugün hedefimi tamamladım",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _dailyLiters == null ? Colors.black38 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_doneToday)
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
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
