import 'package:npo_community/features/alumni_running/campaign_repository.dart';
import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';
import 'package:npo_community/features/alumni_running/models/campaign_channel.dart';
import 'package:npo_community/features/alumni_running/models/campaign_shift.dart';
import 'package:npo_community/features/alumni_running/models/candidate_draft.dart';
import 'package:npo_community/models/chat_message.dart';

/// Synthetic, in-memory Campaign Support Hub data for demo builds.
///
/// Every name is obviously fictional and nothing here touches the network.
/// Writes are not supported; the hub renders them as disabled.
class DemoCampaignRepository implements CampaignRepository {
  DemoCampaignRepository({DateTime? now}) : _now = now ?? DateTime.now();

  final DateTime _now;

  static const String _joinedCandidateId = 'demo-1';
  static const String _joinedChannelId = 'demo-channel-1';

  @override
  bool get supportsWrites => false;

  DateTime get _electionDay => DateTime(_now.year, 11, 3);

  @override
  Future<List<AlumniCandidate>> fetchCandidates() async => [
    AlumniCandidate(
      id: 'demo-1',
      name: 'Demo Candidate Avery',
      office: 'Sample City Council, District 1 (demo)',
      electionName: 'Demo General Election',
      electionDate: _electionDay,
      bio:
          'A fictional Emerge alum used to show the Campaign Support Hub. '
          'No real person or campaign.',
      campaignUrl: Uri.parse('https://example.org/demo-avery'),
      volunteerUrl: Uri.parse('https://example.org/demo-avery/volunteer'),
    ),
    AlumniCandidate(
      id: 'demo-2',
      name: 'Demo Candidate Blake',
      office: 'Example County Commission (demo)',
      electionName: 'Demo General Election',
      electionDate: _electionDay,
      status: CandidateRaceStatus.wonPrimary,
      bio: 'Fictional demo candidate who won a fictional primary.',
      donateUrl: Uri.parse('https://example.org/demo-blake/donate'),
    ),
    AlumniCandidate(
      id: 'demo-3',
      name: 'Demo Candidate Casey',
      office: 'Placeholder School Board (demo)',
      electionName: 'Demo General Election',
      electionDate: _electionDay,
      bio: 'Fictional demo candidate with no campaign links yet.',
    ),
  ];

  @override
  Future<bool> fetchCanManageCandidates() async => false;

  @override
  Future<AlumniCandidate> createCandidate(CandidateDraft draft) =>
      Future.error(const CampaignWritesDisabledException());

  @override
  Future<AlumniCandidate> updateCandidate(String id, CandidateDraft draft) =>
      Future.error(const CampaignWritesDisabledException());

  @override
  Future<void> deleteCandidate(String id) =>
      Future.error(const CampaignWritesDisabledException());

  @override
  Future<List<CampaignChannelMembership>> fetchMyChannels() async => const [
    CampaignChannelMembership(
      candidateId: _joinedCandidateId,
      channelId: _joinedChannelId,
    ),
  ];

  @override
  Future<CampaignChannelMembership> joinChannel(String candidateId) =>
      Future.error(const CampaignWritesDisabledException());

  @override
  Future<void> leaveChannel(String candidateId) =>
      Future.error(const CampaignWritesDisabledException());

  @override
  Future<List<ChatMessage>> fetchChannelMessages(String channelId) async {
    if (channelId != _joinedChannelId) return const [];
    final channel = MessageUser(id: 0, username: 'demo-channel');
    final alex = MessageUser(id: 901, username: 'demo_alum_alex');
    final jo = MessageUser(id: 902, username: 'demo_alum_jo');
    return [
      ChatMessage(
        id: 1,
        sender: alex,
        recipient: channel,
        content: 'Demo message: who is free for Saturday canvassing?',
        timestamp: _now.subtract(const Duration(hours: 5)),
        isRead: true,
      ),
      ChatMessage(
        id: 2,
        sender: jo,
        recipient: channel,
        content: 'Demo message: I can bring yard signs!',
        timestamp: _now.subtract(const Duration(hours: 3)),
        isRead: true,
      ),
    ];
  }

  @override
  Future<ChatMessage> sendChannelMessage(String channelId, String content) =>
      Future.error(const CampaignWritesDisabledException());

  @override
  Stream<void> watchChannel(String channelId) => const Stream.empty();

  @override
  void unwatchChannel(String channelId) {}

  @override
  Future<List<CampaignShift>> fetchShifts(String candidateId) async {
    if (candidateId != 'demo-1') return const [];
    final day = DateTime(_now.year, _now.month, _now.day);
    return [
      CampaignShift(
        id: 'demo-shift-1',
        candidateId: candidateId,
        kind: CampaignShiftKind.canvass,
        startsAt: day.add(const Duration(days: 3, hours: 10)),
        endsAt: day.add(const Duration(days: 3, hours: 13)),
        location: 'Sample Park pavilion (demo)',
        capacity: 12,
        remaining: 5,
      ),
      CampaignShift(
        id: 'demo-shift-2',
        candidateId: candidateId,
        kind: CampaignShiftKind.phoneBank,
        startsAt: day.add(const Duration(days: 5, hours: 18)),
        endsAt: day.add(const Duration(days: 5, hours: 20)),
        location: 'Online (demo)',
        capacity: 20,
        remaining: 0,
      ),
    ];
  }

  @override
  Future<List<CampaignShift>> fetchMyShifts() async => const [];

  @override
  Future<CampaignShift> signUpForShift(CampaignShift shift) =>
      Future.error(const CampaignWritesDisabledException());

  @override
  Future<CampaignShift> cancelShift(CampaignShift shift) =>
      Future.error(const CampaignWritesDisabledException());
}
