import 'package:flutter_sms/flutter_sms.dart';
import 'package:ui_prototype/core/services/location_service.dart';

// ...existing code...
class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_Message> _messages = [];
  late GeminiService _geminiService;
  late ChatSession _chatSession;
  final LocationService _locationService = LocationService();
  bool _isLoading = false;
  String? _error;

  void _sendSms(String phoneNumber) async {
    final locationData = await _locationService.getLocation();
    final locationString = locationData != null
        ? 'https://www.google.com/maps/search/?api=1&query=${locationData.latitude},${locationData.longitude}'
        : 'Konum bilgisi alınamadı.';

    final message =
        'Merhaba, bu acil bir durum bildirimidir. Yakınınızın desteğinize ihtiyacı olabilir. Şu anki konumu: $locationString';

    try {
      // Cihazın SMS gönderme yeteneğini kontrol et
      if (!await canSendSMS()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Bu cihaz SMS gönderemiyor. Lütfen gerçek bir cihazda deneyin.')),
        );
        return;
      }

      await sendSMS(
        message: message,
        recipients: [phoneNumber],
        sendDirect: true,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acil durum bildirimi gönderildi.')),
      );
    } on PlatformException catch (error) {
      // PlatformException'ı daha spesifik ele al
      if (error.code == 'device_not_capable') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Bu cihaz SMS gönderemiyor. Lütfen gerçek bir cihazda deneyin.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bildirim gönderilemedi: ${error.message}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bilinmeyen bir hata oluştu: $error')),
      );
    }
  }

  @override
// ...existing code...
