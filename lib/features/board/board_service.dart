import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/features/board/board_member.dart';

class BoardService extends ApiClient {
  static final BoardService _instance = BoardService._internal();
  factory BoardService() => _instance;
  BoardService._internal();

  /// The board roster, officers first.
  ///
  /// The API filters by capability, so a caller without governance read access
  /// simply sees fewer rows rather than an error.
  Future<List<BoardMember>> fetchBoardMembers() async {
    final data = await read(
      urlPath: '/api/board-members/',
      jsonHeaders: authHeaders,
    );

    final rows = data is List
        ? data
        : (data is Map && data['results'] is List)
        ? data['results'] as List
        : const [];

    final members = rows
        .whereType<Map<String, dynamic>>()
        .map(BoardMember.fromJson)
        .toList();

    members.sort((a, b) {
      final byPosition = a.positionRank.compareTo(b.positionRank);
      return byPosition != 0 ? byPosition : a.name.compareTo(b.name);
    });
    return members;
  }
}
