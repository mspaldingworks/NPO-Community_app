import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';

/// The staff-editable fields of an [AlumniCandidate].
///
/// Headshots and win posts are managed in the Django admin, not here. Like
/// the candidate model, this holds public campaign information only.
class CandidateDraft {
  const CandidateDraft({
    required this.name,
    required this.office,
    this.electionName,
    this.electionDate,
    this.status = CandidateRaceStatus.running,
    this.bio,
    this.vanId,
    this.campaignUrl,
    this.donateUrl,
    this.volunteerUrl,
    this.infoUrl,
  });

  factory CandidateDraft.fromCandidate(AlumniCandidate candidate) =>
      CandidateDraft(
        name: candidate.name,
        office: candidate.office,
        electionName: candidate.electionName,
        electionDate: candidate.electionDate,
        status: candidate.status == CandidateRaceStatus.unknown
            ? CandidateRaceStatus.running
            : candidate.status,
        bio: candidate.bio,
        vanId: candidate.vanId,
        campaignUrl: candidate.campaignUrl,
        donateUrl: candidate.donateUrl,
        volunteerUrl: candidate.volunteerUrl,
        infoUrl: candidate.infoUrl,
      );

  final String name;
  final String office;
  final String? electionName;
  final DateTime? electionDate;
  final CandidateRaceStatus status;
  final String? bio;
  final int? vanId;
  final Uri? campaignUrl;
  final Uri? donateUrl;
  final Uri? volunteerUrl;
  final Uri? infoUrl;

  /// The request body for create (`POST`) and update (`PATCH`). Cleared
  /// optional fields are sent as `null` so the server removes them.
  Map<String, dynamic> toJson() => {
    'name': name,
    'office': office,
    'election_name': electionName,
    'election_date': electionDate == null ? null : _isoDate(electionDate!),
    'status': status.wireValue,
    'bio': bio,
    'van_id': vanId,
    'campaign_url': campaignUrl?.toString(),
    'donate_url': donateUrl?.toString(),
    'volunteer_url': volunteerUrl?.toString(),
    'info_url': infoUrl?.toString(),
  };

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Parses an optional link field. Returns `null` for blank input and
  /// throws [FormatException] for anything other than an absolute HTTPS URL,
  /// matching what [AlumniCandidate.fromJson] will accept back.
  static Uri? parseLink(String? input) {
    final text = input?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Enter a full https:// link.');
    }
    return uri;
  }
}
