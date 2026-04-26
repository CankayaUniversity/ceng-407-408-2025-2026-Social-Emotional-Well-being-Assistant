class MedicineDose {
  String timeHHmm;
  bool taken;

  MedicineDose({required this.timeHHmm, this.taken = false});

  Map<String, dynamic> toMap() => {
    'timeHHmm': timeHHmm,
    'taken': taken,
  };

  factory MedicineDose.fromMap(Map<dynamic, dynamic> map) => MedicineDose(
    timeHHmm: map['timeHHmm'] as String,
    taken: map['taken'] as bool,
  );
}

class MedicinePlan {
  final String id;
  final String name;
  final List<MedicineDose> doses;

  MedicinePlan({required this.id, required this.name, required this.doses});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'doses': doses.map((d) => d.toMap()).toList(),
  };

  factory MedicinePlan.fromMap(Map<dynamic, dynamic> map) => MedicinePlan(
    id: map['id'] as String,
    name: map['name'] as String,
    doses: (map['doses'] as List).map((d) => MedicineDose.fromMap(d as Map)).toList(),
  );
}
