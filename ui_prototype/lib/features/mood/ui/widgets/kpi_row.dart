import 'package:flutter/material.dart';

class KpiRow extends StatelessWidget {
  final List<_KpiItem> items;
  const KpiRow({super.key, required this.items});

  factory KpiRow.simple({
    required String aTitle,
    required String aValue,
    required String bTitle,
    required String bValue,
    required String cTitle,
    required String cValue,
    String? dTitle,
    String? dValue,
  }) {
    final list = <_KpiItem>[
      _KpiItem(aTitle, aValue),
      _KpiItem(bTitle, bValue),
      _KpiItem(cTitle, cValue),
    ];
    if (dTitle != null && dValue != null) list.add(_KpiItem(dTitle, dValue));
    return KpiRow(items: list);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map(
            (e) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F7F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                const SizedBox(height: 6),
                Text(e.value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      )
          .toList()
        ..removeLast() // sonuncunun sağ margin’i olmasın
        ..add(Expanded(child: _KpiBoxNoRightMargin(item: items.last))),
    );
  }
}

class _KpiBoxNoRightMargin extends StatelessWidget {
  final _KpiItem item;
  const _KpiBoxNoRightMargin({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(item.value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _KpiItem {
  final String title;
  final String value;
  _KpiItem(this.title, this.value);
}
