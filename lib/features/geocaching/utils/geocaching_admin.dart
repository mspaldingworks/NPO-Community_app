import 'package:transconnect/models/user.dart';

bool isGeocachingAdmin(User? me) {
  final username = me?.username;
  return username == 'Mad.E' || username == 'Mad.E.Made' || username == 'pmaxwell';
}
