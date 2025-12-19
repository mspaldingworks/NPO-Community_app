import 'dart:convert';

import 'package:crypto/crypto.dart';

String hashCachePassword({required String cacheId, required String password}) {
  final input = '$cacheId:${password.trim()}';
  return sha256.convert(utf8.encode(input)).toString();
}

bool verifyCachePassword({
  required String cacheId,
  required String password,
  required String passwordHash,
}) {
  return hashCachePassword(cacheId: cacheId, password: password) == passwordHash;
}
