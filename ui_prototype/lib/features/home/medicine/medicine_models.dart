class MedicineDose {
  String timeHHmm;
  bool taken;

  MedicineDose({required this.timeHHmm, this.taken = false});
}

class MedicinePlan {
  final String id;
  final String name;
  final List<MedicineDose> doses;

  MedicinePlan({required this.id, required this.name, required this.doses});
}
