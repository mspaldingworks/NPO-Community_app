/// Ways an alumna can help, mirroring VOLUNTEER_ROLES on the API. The key is
/// what the server stores; the values are what members read.
const Map<String, String> volunteerRoles = {
  'mentor': 'Mentor a candidate',
  'host': 'Host an event',
  'speak': 'Speak on a panel',
  'door_knock': 'Knock doors',
  'phone_bank': 'Phone bank',
  'fundraise': 'Help fundraise',
};

/// Short forms for chips and directory rows.
const Map<String, String> volunteerRoleShortLabels = {
  'mentor': 'Mentor',
  'host': 'Host',
  'speak': 'Speaker',
  'door_knock': 'Door knocker',
  'phone_bank': 'Phone banker',
  'fundraise': 'Fundraiser',
};

String volunteerRoleLabel(String key) => volunteerRoles[key] ?? key;

String volunteerRoleShortLabel(String key) =>
    volunteerRoleShortLabels[key] ?? volunteerRoleLabel(key);
