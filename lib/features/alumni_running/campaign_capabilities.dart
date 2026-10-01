/// Typed rendering decisions for the Campaign Support Hub.
///
/// These only decide what the client shows. The server remains the
/// authority: every write can still be refused with `403`.
class CampaignCapabilities {
  const CampaignCapabilities({
    required this.writesEnabled,
    this.reason,
    this.managementGranted = false,
  });

  /// Joining/leaving channels, posting, and shift sign-ups.
  final bool writesEnabled;

  /// Whether the server granted candidate management to this user.
  final bool managementGranted;

  /// Why writes are disabled, for display.
  final String? reason;

  bool get canJoinChannels => writesEnabled;
  bool get canSignUpForShifts => writesEnabled;

  /// Adding, editing, and removing candidates. Needs both the server grant
  /// and a context where writes are allowed (not demo, not Role Preview).
  bool get canManageCandidates => writesEnabled && managementGranted;

  bool canPostIn({required bool joined}) => writesEnabled && joined;

  static const CampaignCapabilities readOnlyDemo = CampaignCapabilities(
    writesEnabled: false,
    reason: 'Joining, posting, and sign-ups are disabled in the demo.',
  );

  static const CampaignCapabilities readOnlyPreview = CampaignCapabilities(
    writesEnabled: false,
    reason: 'Changes are disabled while previewing another role.',
  );

  static const CampaignCapabilities full = CampaignCapabilities(
    writesEnabled: true,
  );
}
