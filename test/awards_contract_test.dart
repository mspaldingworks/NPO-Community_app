// Pins the award JSON the app reads against what the API sends. The API side
// is NPO-Community_api/npo_community_api/test_awards.py (AWARD_KEYS and
// GRANT_KEYS); change both together.

import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/features/awards/awards_service.dart';

/// Must match AWARD_KEYS in the API's test_awards.py.
const awardKeys = <String>{
  'id',
  'key',
  'name',
  'description',
  'icon',
  'color',
  'category',
  'category_label',
  'automatic',
  'threshold',
  'rule_label',
  'unit',
};

/// Must match GRANT_KEYS in the API's test_awards.py.
const grantKeys = <String>{
  'id',
  'award',
  'citation',
  'automatic',
  'granted_at',
  'granted_by',
};

Map<String, dynamic> _award() => {
  'id': 3,
  'key': 'regular',
  'name': 'Regular',
  'description': 'Checked in at five events.',
  'icon': 'celebration',
  'color': '#197278',
  'category': 'showing_up',
  'category_label': 'Showing up',
  'automatic': true,
  'threshold': 5,
  'rule_label': 'Events attended',
  'unit': 'events',
};

void main() {
  test('the sample payloads carry exactly the contract keys', () {
    expect(_award().keys.toSet(), awardKeys);
    final grant = {
      'id': 1,
      'award': _award(),
      'citation': '',
      'automatic': true,
      'granted_at': '2026-10-25T14:00:00Z',
      'granted_by': null,
    };
    expect(grant.keys.toSet(), grantKeys);
    final parsed = AwardGrant.fromJson(grant);
    expect(parsed.award.goal, '5 events');
    expect(parsed.grantedAt, isNotNull);
    expect(parsed.grantedBy, isNull);
  });

  test('every icon the API allows has a drawing', () {
    // awards.ICONS in the API.
    const apiIcons = [
      'star',
      'trophy',
      'medal',
      'ribbon',
      'heart',
      'handshake',
      'campaign',
      'ballot',
      'volunteer',
      'school',
      'groups',
      'diversity',
      'celebration',
      'event',
      'forum',
      'savings',
      'rocket',
      'flag',
      'lightbulb',
    ];
    expect(awardIcons.keys.toSet(), apiIcons.toSet());
  });

  test('colors round-trip through hex', () {
    for (final color in awardColors) {
      expect(colorFromHex(hexFromColor(color)), color);
    }
    expect(hexFromColor(colorFromHex('#5071ce')), '#5071CE');
  });
}
