class PublicConfig {
  const PublicConfig({
    required this.matomoUrl,
    required this.matomoSiteId,
    required this.mapTileUrl,
    required this.mapAttribution,
  });

  final String matomoUrl;
  final String matomoSiteId;
  final String mapTileUrl;
  final String mapAttribution;

  bool get matomoConfigured => matomoUrl.isNotEmpty && matomoSiteId.isNotEmpty;

  factory PublicConfig.fromJson(Map<String, dynamic> json) => PublicConfig(
    matomoUrl: (json['MATOMO_URL'] ?? '') as String,
    matomoSiteId: (json['MATOMO_SITE_ID'] ?? '') as String,
    mapTileUrl: (json['MAP_TILE_URL'] ??
            'https://tile.openstreetmap.org/{z}/{x}/{y}.png')
        as String,
    mapAttribution: (json['MAP_ATTRIBUTION'] ??
            '© OpenStreetMap contributors')
        as String,
  );

  factory PublicConfig.defaults() => const PublicConfig(
    matomoUrl: '',
    matomoSiteId: '',
    mapTileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    mapAttribution: '© OpenStreetMap contributors',
  );
}
