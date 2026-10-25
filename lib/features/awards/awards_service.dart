import 'package:http/http.dart' as http;
import 'package:npo_community/core/config/app_config.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/features/awards/models/award.dart';

export 'package:npo_community/features/awards/models/award.dart';

/// Awards (/api/awards/) and candidate support on the Ballot page
/// (/api/candidates/). Rules live in the API's awards.py.
class AwardsService extends ApiClient {
  AwardsService();

  // -- members -----------------------------------------------------------------

  /// The catalog with the viewer's progress, and the awards they hold.
  Future<AwardCatalog> fetchCatalog({bool includeRetired = false}) async {
    final data = await read(
      urlPath: includeRetired
          ? '/api/awards/?include_retired=1'
          : '/api/awards/',
      jsonHeaders: authHeaders,
    );
    return AwardCatalog.fromJson(data as Map<String, dynamic>);
  }

  /// The awards on a member's profile, newest first.
  Future<List<AwardGrant>> fetchMemberAwards(int userId) async =>
      AwardGrant.listFromJson(
        await read(
          urlPath: '/api/users/$userId/awards/',
          jsonHeaders: authHeaders,
        ),
      );

  // -- candidate support -------------------------------------------------------

  /// Support for every alumna on the ballot, keyed by seed id.
  Future<Map<String, CandidateSupport>> fetchCandidateSupport() async {
    final data = await read(
      urlPath: '/api/candidates/support/',
      jsonHeaders: authHeaders,
    );
    return {
      for (final entry in (data as Map<String, dynamic>).entries)
        entry.key: CandidateSupport.fromJson(
          entry.value as Map<String, dynamic>,
        ),
    };
  }

  Future<CandidateSupport> setCandidateSupport(
    String seedId,
    SupportKind kind, {
    required bool active,
  }) async => CandidateSupport.fromJson(
    await post(
          urlPath: '/api/candidates/$seedId/support/',
          jsonHeaders: authHeaders,
          jsonPayload: {'kind': kind.key, 'active': active},
        )
        as Map<String, dynamic>,
  );

  // -- administrators ----------------------------------------------------------

  Future<AwardOptions> fetchOptions() async => AwardOptions.fromJson(
    await read(urlPath: '/api/awards/options/', jsonHeaders: authHeaders)
        as Map<String, dynamic>,
  );

  Future<Award> createAward(Map<String, dynamic> fields) async =>
      Award.fromJson(
        await post(
              urlPath: '/api/awards/',
              jsonHeaders: authHeaders,
              jsonPayload: fields,
              expectedStatusCode: 201,
            )
            as Map<String, dynamic>,
      );

  Future<Award> updateAward(int id, Map<String, dynamic> fields) async =>
      Award.fromJson(
        await update(
              urlPath: '/api/awards/$id/',
              jsonHeaders: authHeaders,
              jsonPayload: fields,
            )
            as Map<String, dynamic>,
      );

  Future<List<AwardGrant>> fetchHolders(int awardId) async =>
      AwardGrant.listFromJson(
        await read(
          urlPath: '/api/awards/$awardId/holders/',
          jsonHeaders: authHeaders,
        ),
      );

  /// Gives the award to each member. Returns the new grants (automatic
  /// awards skip anyone who already holds them).
  Future<List<AwardGrant>> grantAward(
    int awardId,
    List<int> accountIds, {
    String citation = '',
  }) async => AwardGrant.listFromJson(
    await post(
      urlPath: '/api/awards/$awardId/grant/',
      jsonHeaders: authHeaders,
      jsonPayload: {'account_ids': accountIds, 'citation': citation},
      expectedStatusCode: 201,
    ),
  );

  Future<void> revokeGrant(int grantId) async {
    await post(
      urlPath: '/api/awards/grants/$grantId/revoke/',
      jsonHeaders: authHeaders,
      jsonPayload: const {},
      expectedStatusCode: 204,
    );
  }

  /// Members to choose from when giving an award: only those it can go to
  /// (alumni for alumni awards, the class for class achievements).
  Future<List<AwardMember>> searchMembers(String query, {int? awardId}) async {
    final data = await read(
      urlPath:
          '/api/awards/members/?search=${Uri.encodeQueryComponent(query)}'
          '${awardId == null ? '' : '&award=$awardId'}',
      jsonHeaders: authHeaders,
    );
    return [
      for (final row in (data as List))
        AwardMember.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// Replaces an award's artwork with the image at [path].
  Future<Award> uploadImage(int awardId, String path) async {
    final request =
        http.MultipartRequest(
            'POST',
            AppConfig.current.apiUri('/api/awards/$awardId/image/'),
          )
          ..headers['Authorization'] = authHeaders['Authorization'] ?? ''
          ..files.add(await http.MultipartFile.fromPath('image', path));
    final response = await http.Response.fromStream(
      await httpClient.send(request),
    );
    if (response.statusCode != 200) {
      throw ApiClientException(
        extractErrorMessage(tryDecodeJson(response.body), response.statusCode),
      );
    }
    return Award.fromJson(tryDecodeJson(response.body) as Map<String, dynamic>);
  }

  /// Removes custom artwork; the app draws the icon instead.
  Future<Award> removeImage(int awardId) async => Award.fromJson(
    await delete(
          urlPath: '/api/awards/$awardId/image/',
          jsonHeaders: authHeaders,
          expectedStatusCode: 200,
        )
        as Map<String, dynamic>,
  );
}
