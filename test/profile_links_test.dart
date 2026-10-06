// Profile links: parsed from the API, normalised on the way back, and given
// a recognisable icon.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/core/utils/profile_links.dart';
import 'package:npo_community/models/user.dart';

void main() {
  test('User reads links and ignores rows without a url', () {
    final user = User.fromJson({
      'id': 1,
      'username': 'ava',
      'links': [
        {'label': 'Instagram', 'url': 'https://instagram.com/ava'},
        {'label': '', 'url': 'https://www.ava.example.org'},
        {'label': 'broken'},
      ],
    });
    expect(user.links, [
      const ProfileLink(label: 'Instagram', url: 'https://instagram.com/ava'),
      const ProfileLink(label: '', url: 'https://www.ava.example.org'),
    ]);
    expect(user.links.last.displayLabel, 'ava.example.org');
    expect(user.links.first.toJson(), {
      'label': 'Instagram',
      'url': 'https://instagram.com/ava',
    });
  });

  test('typed URLs get an https scheme', () {
    expect(
      normalizeProfileLinkUrl('  instagram.com/ava '),
      'https://instagram.com/ava',
    );
    expect(normalizeProfileLinkUrl('http://x.com/ava'), 'https://x.com/ava');
    expect(normalizeProfileLinkUrl('https://x.com/ava'), 'https://x.com/ava');
    expect(normalizeProfileLinkUrl('   '), '');
  });

  test('icons follow the label, then the host', () {
    expect(
      iconForProfileLink(
        const ProfileLink(
          label: 'Campaign',
          url: 'https://www.facebook.com/ava',
        ),
      ),
      Icons.facebook,
    );
    expect(
      iconForProfileLink(
        const ProfileLink(label: 'LinkedIn', url: 'https://lnkd.in/x'),
      ),
      Icons.work_outline,
    );
    expect(
      iconForProfileLink(
        const ProfileLink(label: 'My site', url: 'https://ava.example.org'),
      ),
      Icons.link,
    );
  });
}
