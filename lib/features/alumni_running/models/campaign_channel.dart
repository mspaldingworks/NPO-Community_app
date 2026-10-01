/// The current user's membership in a candidate's supporter channel.
///
/// The server issues an opaque [channelId] for the existing chat channel
/// endpoints. Membership is political-opinion data and lives only in the
/// in-memory session cache.
class CampaignChannelMembership {
  const CampaignChannelMembership({
    required this.candidateId,
    required this.channelId,
  });

  final String candidateId;
  final String channelId;

  factory CampaignChannelMembership.fromJson(Map<String, dynamic> json) {
    final candidateId = json['candidate_id']?.toString().trim() ?? '';
    final channelId = json['channel_id']?.toString().trim() ?? '';
    if (candidateId.isEmpty || channelId.isEmpty) {
      throw const FormatException('Channel membership is incomplete');
    }
    return CampaignChannelMembership(
      candidateId: candidateId,
      channelId: channelId,
    );
  }
}
