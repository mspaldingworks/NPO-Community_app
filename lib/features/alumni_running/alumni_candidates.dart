import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';

/// Emerge Kentucky alumni on the ballot in the 2026 general election.
///
/// Curated public information. Add new candidates here; set `campaignUrl`
/// to the live campaign page once it is confirmed, otherwise `infoUrl`
/// points at a public candidate profile.
const String alumniCandidatesElection = '2026 General Election · Nov. 3, 2026';

final List<AlumniCandidate> alumniCandidates2026 = List.unmodifiable([
  AlumniCandidate(
    name: 'Christian Furman',
    office: 'Kentucky State Senate, District 6',
    election: alumniCandidatesElection,
    campaignUrl: Uri.parse('https://christianforky.com/'),
    infoUrl: Uri.parse('https://ballotpedia.org/Christian_Furman'),
  ),
  AlumniCandidate(
    name: 'Amy Olson',
    office: 'St. Matthews City Council, At-large',
    election: alumniCandidatesElection,
    infoUrl: Uri.parse(
      'https://ballotpedia.org/Amy_Olson_(Saint_Matthews_City_Council_At-large,_Kentucky,_candidate_2026)',
    ),
  ),
  AlumniCandidate(
    name: 'Serenity Johnson',
    office: 'Radcliff City Council, At-large',
    election: alumniCandidatesElection,
    infoUrl: Uri.parse(
      'https://ballotpedia.org/Serenity_Johnson_(Radcliff_City_Council_At-large,_Kentucky,_candidate_2026)',
    ),
  ),
]);
