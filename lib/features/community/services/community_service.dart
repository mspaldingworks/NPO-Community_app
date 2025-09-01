import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:transconnect/features/community/models/group_model.dart';

class CommunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Group>> fetchGroups() async {
    try {
      final snapshot = await _firestore.collection('communityUsers').get();
      return snapshot.docs.map((doc) => Group.fromSnapshot(doc)).toList();
    } catch (e) {
      // It's a good practice to handle potential errors, e.g., permissions.
      print('Error fetching groups: $e');
      throw Exception('Error fetching groups: $e');
    }
  }
}
