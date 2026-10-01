import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';
import 'package:npo_community/features/alumni_running/models/campaign_channel.dart';
import 'package:npo_community/features/alumni_running/models/campaign_shift.dart';
import 'package:npo_community/models/chat_message.dart';

/// Thrown when a write is attempted where writes are not allowed
/// (demo builds, Role Preview).
class CampaignWritesDisabledException implements Exception {
  const CampaignWritesDisabledException([
    this.message = 'Changes are disabled in this mode.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Data source for the Campaign Support Hub.
///
/// The live implementation talks to the API; the demo implementation is
/// synthetic and in-memory. They are chosen at the composition root.
abstract class CampaignRepository {
  /// Whether this source accepts writes at all. Demo sources do not.
  bool get supportsWrites;

  Future<List<AlumniCandidate>> fetchCandidates();

  /// Supporter channels the current user has joined.
  Future<List<CampaignChannelMembership>> fetchMyChannels();

  Future<CampaignChannelMembership> joinChannel(String candidateId);

  Future<void> leaveChannel(String candidateId);

  Future<List<ChatMessage>> fetchChannelMessages(String channelId);

  Future<ChatMessage> sendChannelMessage(String channelId, String content);

  /// Emits whenever the channel has new activity. Empty when live updates
  /// are unavailable.
  Stream<void> watchChannel(String channelId);

  void unwatchChannel(String channelId);

  Future<List<CampaignShift>> fetchShifts(String candidateId);

  /// Shifts the current user has signed up for, across all campaigns.
  Future<List<CampaignShift>> fetchMyShifts();

  Future<CampaignShift> signUpForShift(CampaignShift shift);

  Future<CampaignShift> cancelShift(CampaignShift shift);
}
