import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/features/events/events_service.dart';
import 'package:npo_community/core/services/community_service.dart';
import 'package:npo_community/core/services/home_alert_service.dart';
import 'package:npo_community/core/services/profile_service.dart';
import 'package:npo_community/core/utils/flair_utils.dart';
import 'package:npo_community/features/onboarding_tour/widgets/tour_anchor.dart';
import 'package:npo_community/models/comment.dart';
import 'package:npo_community/models/user.dart';
import 'package:npo_community/theme/app_theme.dart';
import 'package:npo_community/widgets/display_profile_pic.dart';
import 'package:npo_community/widgets/emergency_alert_banner.dart';
import 'package:npo_community/widgets/emerge/emerge_components.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Home: the website's quick-link tiles, today's counters (friends,
/// replies, events) and the member's own profile card.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final EventsService _eventsService = EventsService();
  final ProfileService _profileService = ProfileService();
  final CommunityService _communityService = CommunityService();

  static const String _lastSeenRepliesAtPrefKey =
      'dashboard_last_seen_replies_at_v1';
  DateTime _lastSeenRepliesAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _unreadReplyCount = 0;
  int _todaysEventsCount = 0;
  File? _profileImage;
  bool _isLoading = true;
  bool _updatingProfilePic = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  void _updateDashboardAlerts() {
    Provider.of<HomeAlertService>(
      context,
      listen: false,
    ).setDashboardAlerts(_todaysEventsCount > 0 || _unreadReplyCount > 0);
  }

  Future<void> _loadDashboardData() async {
    await _loadLastSeenRepliesAt();
    List<CommunityEvent> allEvents = const [];
    try {
      allEvents = await _eventsService.fetchEvents();
    } catch (_) {
      // The counter is a nicety; the Events tab reports the real error.
    }
    final imagePath = await _profileService.getImagePath();
    final now = DateTime.now();
    final weekOut = now.add(const Duration(days: 7));

    final todaysEvents = allEvents.where((event) {
      return !event.isCancelled &&
          event.startsAt.isBefore(weekOut) &&
          (event.endsAt ?? event.startsAt).isAfter(now);
    }).length;
    final unreadReplyCount = await _computeUnreadReplyCount();

    if (!mounted) return;
    setState(() {
      _todaysEventsCount = todaysEvents;
      _unreadReplyCount = unreadReplyCount;
      if (imagePath != null) _profileImage = File(imagePath);
      _isLoading = false;
    });
    _updateDashboardAlerts();
  }

  // -- replies to the member's own posts ------------------------------------

  Future<void> _loadLastSeenRepliesAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSeenRepliesAtPrefKey);
    if (raw == null || raw.trim().isEmpty) {
      final now = DateTime.now();
      await prefs.setString(_lastSeenRepliesAtPrefKey, now.toIso8601String());
      if (!mounted) return;
      setState(() {
        _lastSeenRepliesAt = now;
        _unreadReplyCount = 0;
      });
      return;
    }
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null || !mounted) return;
    setState(() {
      _lastSeenRepliesAt = parsed;
    });
  }

  Future<void> _markRepliesRead() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(_lastSeenRepliesAtPrefKey, now.toIso8601String());
    if (!mounted) return;
    setState(() {
      _lastSeenRepliesAt = now;
      _unreadReplyCount = 0;
    });
    _updateDashboardAlerts();
  }

  DateTime? _tryParseCommentTimestamp(Comment c) {
    final raw = (c.updatedAt != null && c.updatedAt!.trim().isNotEmpty)
        ? c.updatedAt!
        : c.pubDate;
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<int> _computeUnreadReplyCount() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    var me = auth.currentUser;
    try {
      me ??= await auth.getCurrentUser();
    } catch (_) {}
    if (me == null) return 0;

    try {
      final posts = await _communityService.fetchAllPosts();
      var count = 0;
      for (final p in posts.where((p) => p.author == me!.id)) {
        for (final c in p.comments) {
          final ts = _tryParseCommentTimestamp(c);
          if (ts == null || !ts.isAfter(_lastSeenRepliesAt)) continue;
          if (c.authorId == me.id || c.authorUsername == me.username) continue;
          count += 1;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  // -- profile photo --------------------------------------------------------

  Future<void> _pickAndUploadProfilePic() async {
    if (_updatingProfilePic) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    final me = auth.currentUser;
    if (me == null) return;
    final messenger = ScaffoldMessenger.of(context);

    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to open photo picker: $e')),
      );
      return;
    }
    if (picked == null) return;

    setState(() => _updatingProfilePic = true);
    try {
      await _profileService.saveProfile(
        (me.statusMessage ?? '').trim(),
        picked.path,
      );
      await auth.getProfile();
      if (!mounted) return;
      setState(() => _profileImage = File(picked!.path));
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile picture updated.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update profile picture: $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingProfilePic = false);
    }
  }

  // -- layout ---------------------------------------------------------------

  /// The website's home quick-link touts reproduced as a 2x2 tile grid, with
  /// the website's FOLLOW US tile swapped for the in-app Ballot page. Calendar
  /// and Ballot stay in-app; News and Join open ky.emergeamerica.org.
  Widget _buildEmergeTouts(BuildContext context) {
    Future<void> open(String url) async {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: EmergeActionTile(
                label: 'Calendar',
                icon: Icons.calendar_month_outlined,
                onTap: () => context.push('/events'),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: EmergeActionTile(
                label: 'Recent News',
                icon: Icons.article_outlined,
                background: AppColors.primary,
                foreground: AppColors.textWhite,
                onTap: () => open('https://ky.emergeamerica.org/news/'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: EmergeActionTile(
                label: 'Join Our Movement',
                icon: Icons.emoji_objects_outlined,
                background: AppColors.primary,
                foreground: AppColors.textWhite,
                onTap: () => open('https://ky.emergeamerica.org/get-involved/'),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: EmergeActionTile(
                key: const Key('ballot-tile'),
                label: 'Ballot',
                icon: Icons.how_to_vote_outlined,
                background: AppColors.primaryDark,
                foreground: AppColors.textWhite,
                onTap: () => context.push('/alumni/running'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final replies = _unreadReplyCount;
    final repliesText = replies <= 0
        ? 'No new replies'
        : (replies > 99
              ? '99+ new replies'
              : '$replies new ${replies == 1 ? 'reply' : 'replies'}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          TourAnchor(
            name: 'Settings',
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/profile/settings'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const EmergencyAlertBanner(),
            _buildEmergeTouts(context),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TourAnchor(
                  name: 'Messages',
                  child: _buildInfoCard(
                    Icons.chat,
                    'Messages',
                    onTap: () => context.push('/chat'),
                  ),
                ),
                TourAnchor(
                  name: 'Replies',
                  child: _buildInfoCard(
                    Icons.mark_email_unread_outlined,
                    repliesText,
                    onTap: () async {
                      if (_unreadReplyCount > 0) {
                        await _markRepliesRead();
                        if (!context.mounted) return;
                      }
                      context.push('/community');
                    },
                    isHighlighted: replies > 0,
                  ),
                ),
                TourAnchor(
                  name: 'Upcoming events',
                  child: _buildInfoCard(
                    Icons.calendar_today_outlined,
                    _isLoading ? '...' : '$_todaysEventsCount events this week',
                    onTap: () => context.push('/events'),
                    isHighlighted: _todaysEventsCount > 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildProfileAvatar(),
            const SizedBox(height: 16),
            TourAnchor(name: 'Edit Profile', child: _buildEditProfileButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String text, {
    VoidCallback? onTap,
    bool isHighlighted = false,
    // The brand green of the compose button, so highlights read as "go".
    Color highlightColor = AppColors.green,
  }) {
    final Color backgroundColor = isHighlighted
        ? highlightColor
        : Colors.grey[200]!;
    final Color contentColor = isHighlighted ? Colors.white : Colors.grey[700]!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        height: 90,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: highlightColor.withValues(alpha: 0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : const [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: contentColor),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: contentColor,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuickEditProfileSheet() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final me = auth.currentUser;
    if (me == null) return;

    final statusCtrl = TextEditingController(
      text: (me.statusMessage ?? '').trim(),
    );
    final cityCtrl = TextEditingController(text: (me.city ?? '').trim());
    final pronounsCtrl = TextEditingController(
      text: (FlairUtils.extractPronouns(me.flair) ?? '').trim(),
    );
    bool saving = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Future<void> handleSave() async {
                if (saving) return;
                setSheetState(() => saving = true);

                final status = statusCtrl.text.trim();
                final city = cityCtrl.text.trim();
                final flair = FlairUtils.buildFlair(
                  pronouns: pronounsCtrl.text.trim(),
                  isPrivateProfile: FlairUtils.isProfilePrivate(me.flair),
                );
                final updates = <String, dynamic>{
                  'status_message': status,
                  'city': city,
                  'flair': flair,
                };
                final optimisticUser = User(
                  id: me.id,
                  username: me.username,
                  email: me.email,
                  city: city.isEmpty ? null : city,
                  statusMessage: status.isEmpty ? null : status,
                  statusUpdatedAt: DateTime.now(),
                  flair: flair,
                  profilePic: me.profilePic,
                  friends: me.friends,
                  userType: me.userType,
                  isStaff: me.isStaff,
                  isSuperuser: me.isSuperuser,
                  canModerate: me.canModerate,
                  verificationTier: me.verificationTier,
                  programYear: me.programYear,
                  fullName: me.fullName,
                );

                try {
                  await auth.updateProfileOptimistically(
                    updates: updates,
                    optimisticUser: optimisticUser,
                  );
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update profile: $e')),
                  );
                  if (!sheetContext.mounted) return;
                  setSheetState(() => saving = false);
                }
              }

              final bottom = MediaQuery.of(sheetContext).viewInsets.bottom;
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 16 + bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Quick edit',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: statusCtrl,
                      enabled: !saving,
                      maxLength: 140,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pronounsCtrl,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'Pronouns',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cityCtrl,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: saving ? null : handleSave,
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: saving
                          ? null
                          : () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      statusCtrl.dispose();
      cityCtrl.dispose();
      pronounsCtrl.dispose();
    }
  }

  Widget _buildProfileAvatar() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final imageUrl = authService.currentUser?.fullProfilePicUrl;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _showQuickEditProfileSheet,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              if (_profileImage != null)
                CircleAvatar(
                  radius: 40,
                  backgroundImage: FileImage(_profileImage!),
                )
              else
                DisplayProfilePic(radius: 40, imageUrl: imageUrl),
              if (_updatingProfilePic)
                const Positioned(
                  bottom: 4,
                  right: 4,
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Change profile photo',
                    onPressed: _updatingProfilePic
                        ? null
                        : _pickAndUploadProfilePic,
                    icon: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black54,
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditProfileButton() {
    return Center(
      child: ElevatedButton(
        onPressed: () => context.push('/profile'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.textBlack,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        ),
        child: const Text('Edit Profile'),
      ),
    );
  }
}
