import 'package:flutter/material.dart';
import 'package:npo_community/models/user.dart';

/// A quick-add option on the Edit Profile screen: the label it fills in and
/// the start of the URL, so a member only types her handle.
class ProfileLinkPreset {
  const ProfileLinkPreset(this.label, this.icon, {this.urlPrefix = 'https://'});

  final String label;
  final IconData icon;
  final String urlPrefix;
}

/// The platforms we offer by name. "Website" and "Other" cover the rest.
const List<ProfileLinkPreset> profileLinkPresets = [
  ProfileLinkPreset(
    'Instagram',
    Icons.photo_camera_outlined,
    urlPrefix: 'https://instagram.com/',
  ),
  ProfileLinkPreset(
    'Facebook',
    Icons.facebook,
    urlPrefix: 'https://facebook.com/',
  ),
  ProfileLinkPreset(
    'LinkedIn',
    Icons.work_outline,
    urlPrefix: 'https://linkedin.com/in/',
  ),
  ProfileLinkPreset('X', Icons.alternate_email, urlPrefix: 'https://x.com/'),
  ProfileLinkPreset(
    'Bluesky',
    Icons.cloud_outlined,
    urlPrefix: 'https://bsky.app/profile/',
  ),
  ProfileLinkPreset(
    'Threads',
    Icons.forum_outlined,
    urlPrefix: 'https://threads.net/@',
  ),
  ProfileLinkPreset(
    'TikTok',
    Icons.music_note_outlined,
    urlPrefix: 'https://tiktok.com/@',
  ),
  ProfileLinkPreset(
    'YouTube',
    Icons.play_circle_outline,
    urlPrefix: 'https://youtube.com/@',
  ),
  ProfileLinkPreset('Website', Icons.language),
  ProfileLinkPreset('Other', Icons.link),
];

/// The icon for a link, by its label first and then by its host, so a link
/// labelled "Campaign" that points at Facebook still gets the Facebook mark.
IconData iconForProfileLink(ProfileLink link) {
  final label = link.label.trim().toLowerCase();
  final host = (Uri.tryParse(link.url)?.host ?? '').toLowerCase();
  for (final preset in profileLinkPresets) {
    final name = preset.label.toLowerCase();
    if (name == 'website' || name == 'other') continue;
    final presetHost = Uri.tryParse(preset.urlPrefix)?.host ?? '';
    if (label == name || (presetHost.isNotEmpty && host.endsWith(presetHost))) {
      return preset.icon;
    }
  }
  if (host.endsWith('twitter.com')) return Icons.alternate_email;
  return Icons.link;
}

/// The URL a member typed, made ready for the API: trimmed, and given an
/// https scheme when she left it off ("instagram.com/me").
String normalizeProfileLinkUrl(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return '';
  if (text.startsWith('https://')) return text;
  if (text.startsWith('http://')) return 'https://${text.substring(7)}';
  return 'https://$text';
}
