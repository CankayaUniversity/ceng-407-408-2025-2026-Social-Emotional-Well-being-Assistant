import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ui_prototype/core/api/api_client.dart';

class EventModel {
  final String id;
  final String title;
  final String date;
  final String location;
  final String imageUrl;
  final String category;
  final String? link;

  EventModel({
    required this.id,
    required this.title,
    required this.date,
    required this.location,
    required this.imageUrl,
    required this.category,
    this.link,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Başlıksız Etkinlik',
      date: json['date']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=500&q=80',
      category: json['category']?.toString() ?? 'Etkinlik',
      link: json['link']?.toString(),
    );
  }
}

class EventService {
  static final EventService _instance = EventService._internal();
  factory EventService() => _instance;
  EventService._internal();

  Future<List<EventModel>> fetchUpcomingEvents() async {
    try {
      final response = await ApiClient.get('/events');
      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);
        return decoded.map((e) => EventModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('FETCH EVENTS ERROR: $e');
    }

    // Fallback to empty list if API fails
    return [];
  }
}
