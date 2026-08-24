import 'package:vmito_app/features/home/domain/home_discovery_tab.dart';

class DiscoverySuggestion {
  const DiscoverySuggestion({
    required this.tab,
    required this.entityId,
    required this.title,
    this.subtitle,
    this.imageUrl,
  });

  final HomeDiscoveryTab tab;
  final String entityId;
  final String title;
  final String? subtitle;
  final String? imageUrl;
}
