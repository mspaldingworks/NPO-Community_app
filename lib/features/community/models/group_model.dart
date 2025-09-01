import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String name;

  Group({required this.id, required this.name});

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'].toString(),
      name: json['name'],
    );
  }

  factory Group.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Group(
      id: snapshot.id,
      name: data['name'] ?? 'Unnamed Group',
    );
  }
}
