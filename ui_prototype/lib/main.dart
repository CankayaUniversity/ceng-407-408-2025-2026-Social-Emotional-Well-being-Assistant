import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'features/home/data/home_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ TR tarih/ay isimleri (intl)
  await initializeDateFormatting('tr_TR', null);

  // ✅ Hive init
  await Hive.initFlutter();

  // ✅ HomeStore Hive box'ını aç (token gerekmez)
  await HomeStore.instance.init();

  runApp(const MyApp());
}