enum AppCapability { adminPanel }

class CapabilityService {
  CapabilityService({required Set<AppCapability> grantedCapabilities})
      : _grantedCapabilities = grantedCapabilities;

  final Set<AppCapability> _grantedCapabilities;

  factory CapabilityService.empty() =>
      CapabilityService(grantedCapabilities: <AppCapability>{});

  bool has(AppCapability capability) => _grantedCapabilities.contains(capability);
}
