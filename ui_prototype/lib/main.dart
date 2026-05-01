import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ui_prototype/core/services/global_chat_service.dart';
import 'package:ui_prototype/core/services/notification_service.dart';

import 'app.dart';
import 'features/home/data/home_store.dart';
import 'features/chat/data/chat_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Bildirim servisini başlat
  await NotificationService().init();

  // ✅ Global Chat servisini başlat (Socket'i canlı tutar)
  await GlobalChatService().init();

  // ✅ TR tarih/ay isimleri (intl)
  await initializeDateFormatting('tr_TR', null);

  // ✅ Hive init
  await Hive.initFlutter();

  // ✅ HomeStore Hive box'ını aç (token gerekmez)
  await HomeStore.instance.init();

  // ✅ ChatStore Hive box'ını aç
  await ChatStore.instance.init();

  runApp(const MyApp());
}