import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:transconnect/features/geocaching/models/geocache.dart';
import 'package:transconnect/features/geocaching/models/geocache_query.dart';
import 'package:transconnect/features/geocaching/repositories/geocache_repository.dart';

class GeocacheMapController with ChangeNotifier {
  final GeocacheRepository repo;

  GeocacheQuery _query;
  StreamSubscription<List<Geocache>>? _sub;

  List<Geocache> caches = const [];
  bool loading = true;
  String? error;

  GeocacheMapController({required this.repo, required GeocacheQuery initialQuery})
      : _query = initialQuery;

  GeocacheQuery get query => _query;

  void start() {
    _sub?.cancel();
    loading = true;
    error = null;
    notifyListeners();

    _sub = repo.watchNearby(_query).listen(
      (items) {
        caches = items;
        loading = false;
        notifyListeners();
      },
      onError: (e) {
        error = e.toString();
        loading = false;
        notifyListeners();
      },
    );
  }

  void updateQuery(GeocacheQuery next) {
    _query = next;
    start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
