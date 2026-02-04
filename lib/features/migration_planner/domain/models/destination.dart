enum DestinationType {
  illinoisEntry,
  canadaBorder,
  mexicoBorder,
}

class DestinationPreset {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final DestinationType type;
  final String description;

  const DestinationPreset({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.description,
  });
}
