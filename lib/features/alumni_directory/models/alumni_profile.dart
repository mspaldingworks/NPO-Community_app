/// An Emerge Kentucky alumna as surfaced by the NGP VAN-backed CRM endpoint
/// (`/api/crm/alumni/`). The backend maps VAN "people" (MyCampaign) plus the
/// cohort custom field into this shape so the app never talks to VAN directly.
class AlumniProfile {
  const AlumniProfile({
    required this.vanId,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.city,
    this.state,
    this.cohortYear,
    this.officeSought,
  });

  final int vanId;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? city;
  final String? state;

  /// Emerge KY cohort/program year, from the VAN cohort custom field.
  final int? cohortYear;
  final String? officeSought;

  String get fullName {
    final name = [
      firstName,
      lastName,
    ].where((part) => part.trim().isNotEmpty).join(' ').trim();
    return name.isEmpty ? 'Alumna #$vanId' : name;
  }

  String get initials {
    final first = firstName.trim();
    final last = lastName.trim();
    final a = first.isNotEmpty ? first[0] : '';
    final b = last.isNotEmpty ? last[0] : '';
    final combined = '$a$b'.toUpperCase();
    return combined.isEmpty ? '?' : combined;
  }

  String? get location {
    final parts = [
      city,
      state,
    ].where((part) => part != null && part.trim().isNotEmpty).cast<String>();
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  factory AlumniProfile.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim());
      return null;
    }

    String? asString(dynamic value) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
      return null;
    }

    return AlumniProfile(
      vanId: asInt(json['van_id']) ?? 0,
      firstName: asString(json['first_name']) ?? '',
      lastName: asString(json['last_name']) ?? '',
      email: asString(json['email']),
      phone: asString(json['phone']),
      city: asString(json['city']),
      state: asString(json['state']),
      cohortYear: asInt(json['cohort_year']),
      officeSought: asString(json['office_sought']),
    );
  }
}
