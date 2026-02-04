class MigrationPlannerConfig {
  MigrationPlannerConfig._();

  static const String routingBaseUrl = String.fromEnvironment(
    'ROUTING_BASE_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  static const String tileServerUrl = String.fromEnvironment(
    'TILE_SERVER_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const String restroomBaseUrl = String.fromEnvironment(
    'RESTROOM_BASE_URL',
    defaultValue: 'https://www.refugerestrooms.org/api/v1',
  );
}
