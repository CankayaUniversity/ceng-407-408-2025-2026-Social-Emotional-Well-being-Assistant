import 'dart:async';

class EventModel {
  final String id;
  final String title;
  final String date;
  final String location;
  final String imageUrl;
  final String category;

  EventModel({
    required this.id,
    required this.title,
    required this.date,
    required this.location,
    required this.imageUrl,
    required this.category,
  });
}

class EventService {
  static final EventService _instance = EventService._internal();
  factory EventService() => _instance;
  EventService._internal();

  Future<List<EventModel>> fetchUpcomingEvents() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock data based on typical event sources (Concerts, Theatre, Municipal activities)
    return [
      EventModel(
        id: '1',
        title: 'Sertab Erener Konseri',
        date: '20 Mayıs 2024 - 21:00',
        location: 'Harbiye Açık Hava',
        category: 'Konser',
        imageUrl: 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=500&q=80',
      ),
      EventModel(
        id: '2',
        title: 'Hamlet Tiyatro Oyunu',
        date: '22 Mayıs 2024 - 20:30',
        location: 'Zorlu PSM',
        category: 'Tiyatro',
        imageUrl: 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=500&q=80',
      ),
      EventModel(
        id: '3',
        title: 'İstanbul Kitap Fuarı',
        date: '25 Mayıs 2024 - 10:00',
        location: 'TÜYAP Fuar Merkezi',
        category: 'Fuar',
        imageUrl: 'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=500&q=80',
      ),
      EventModel(
        id: '4',
        title: 'Yaz Sinema Geceleri',
        date: '28 Mayıs 2024 - 21:00',
        location: 'Beşiktaş Sahil',
        category: 'Sinema',
        imageUrl: 'https://images.unsplash.com/photo-1485846234645-a62644f84728?w=500&q=80',
      ),
    ];
  }
}
