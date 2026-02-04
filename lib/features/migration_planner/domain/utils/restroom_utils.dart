import 'package:transconnect/features/migration_planner/domain/models/restroom.dart';

class RestroomUtils {
  RestroomUtils._();

  static List<Restroom> dedupe(List<Restroom> restrooms) {
    final seen = <String>{};
    final unique = <Restroom>[];
    for (final restroom in restrooms) {
      if (seen.add(restroom.dedupeKey)) {
        unique.add(restroom);
      }
    }
    return unique;
  }
}
