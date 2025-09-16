import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class CancellationLinksService {
  static final CancellationLinksService _instance =
      CancellationLinksService._internal();
  factory CancellationLinksService() => _instance;
  CancellationLinksService._internal();

  Map<String, String> _links = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final jsonStr = await rootBundle.loadString(
      'assets/cancellation_links.json',
    );
    final Map<String, dynamic> data = json.decode(jsonStr);
    _links = {
      for (final entry in data.entries)
        entry.key.toLowerCase(): entry.value as String,
    };
    _loaded = true;
  }

  String? getLink(String serviceName) {
    return _links[serviceName.toLowerCase()];
  }

  Map<String, String> get links => Map.unmodifiable(_links);
}
