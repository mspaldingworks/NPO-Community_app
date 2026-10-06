import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/features/events/events_service.dart';
import 'package:npo_community/core/services/home_alert_service.dart';
import 'package:npo_community/core/services/profile_service.dart';
import 'package:npo_community/core/utils/flair_utils.dart';
import 'package:npo_community/features/onboarding_tour/widgets/tour_anchor.dart';
import 'package:npo_community/models/user.dart';
import 'package:npo_community/theme/app_theme.dart';
import 'package:npo_community/widgets/display_profile_pic.dart';
import 'package:npo_community/widgets/emergency_alert_banner.dart';
import 'package:npo_community/widgets/emerge/emerge_components.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Home: the website's quick-link tiles (the Events tile lights up when the
/// member has something of her own this week), then her profile photo with
/// the change-photo and Messages buttons beside it.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.eventsService, this.now});

  /// Injected in tests.
  final EventsService? eventsService;

  /// Clock override for tests.
  final DateTime Function()? now;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final EventsService _eventsService =
      widget.eventsService ?? EventsService();
  final ProfileService _profileService = ProfileService();

  /// Events she is going to, volunteering at or saved, starting this week.
  List<CommunityEvent> _myEventsSoon = const [];
  File? _profileImage;
  bool _isLoading = true;
  bool _updatingProfilePic = false;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  void _updateDashboardAlerts() {
    Provider.of<HomeAlertService>(
      context,
      listen: false,
    ).setDashboardAlerts(_myEventsSoon.isNotEmpty);
  }

  Future<void> _loadDashboardData() async {
    List<CommunityEvent> allEvents = const [];
    try {
      allEvents = await _eventsService.fetchEvents();
    } catch (_) {
      // The highlight is a nicety; the Events page reports the real error.
    }
    final imagePath = await _profileService.getImagePath();
    final mine = myEventsSoon(allEvents, _now);

    if (!mounted) return;
    setState(() {
      _myEventsSoon = mine;
      if (imagePath != null) _profileImage = File(imagePath);
      _isLoading = false;
    });
    _updateDashboardAlerts();
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
  /// the website's FOLLOW US tile swapped for the in-app Ballot page. Events
  /// and Ballot stay in-app; News and Join open ky.emergeamerica.org.
  ///
  /// The Events tile glows green when the member has an event of her own
  /// this week. The glow spills past the tile's edges, so the grid is laid
  /// out bottom-up and right-to-left: the Events tile (top-left) is painted
  /// last and its glow sits on top of its neighbours instead of under them.
  Widget _buildEmergeTouts(BuildContext context) {
    Future<void> open(String url) async {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }

    final count = _myEventsSoon.length;
    return Column(
      verticalDirection: VerticalDirection.up,
      children: [
        Row(
          textDirection: TextDirection.rtl,
          children: [
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
            const SizedBox(width: 2),
            Expanded(
              child: EmergeActionTile(
                label: 'Join Our Movement',
                icon: Icons.emoji_objects_outlined,
                background: AppColors.primary,
                foreground: AppColors.textWhite,
                onTap: () => open('https://ky.emergeamerica.org/get-involved/'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(
              child: EmergeActionTile(
                label: 'Recent News',
                icon: Icons.article_outlined,
                background: AppColors.primary,
                foreground: AppColors.textWhite,
                onTap: () => open('https://ky.emergeamerica.org/news/'),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: TourAnchor(
                name: 'Upcoming events',
                child: EmergeActionTile(
                  key: const Key('events-tile'),
                  label: 'Events',
                  icon: Icons.calendar_month_outlined,
                  highlighted: count > 0,
                  badge: count > 0 ? '$count' : null,
                  onTap: () => context.push('/events'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
            if (!_isLoading && _myEventsSoon.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _myEventsSoonLine(),
                key: const Key('events-soon-line'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 28),
            _buildProfileRow(),
            const SizedBox(height: 16),
            TourAnchor(name: 'Edit Profile', child: _buildEditProfileButton()),
          ],
        ),
      ),
    );
  }

  /// "Fall Social is Thursday" or "2 of your events this week".
  String _myEventsSoonLine() {
    if (_myEventsSoon.length == 1) {
      final event = _myEventsSoon.first;
      return '${event.title} is coming up this week.';
    }
    return '${_myEventsSoon.length} of your events are coming up this week.';
  }

  Future<void> _showQuickEditProfileSheet() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final me = auth.currentUser;
    if (me == null) return;

    final statusCtrl = TextEditingController(
      text: (me.statusMessage ?? '').trim(),
    );
    final cityCtrl = TextEditingController(text: (me.city ?? '').trim());
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
                  canAdmin: me.canAdmin,
                  verificationTier: me.verificationTier,
                  programYear: me.programYear,
                  fullName: me.fullName,
                  volunteerRoles: me.volunteerRoles,
                  links: me.links,
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
                    const SizedBox(height: 8),
                    ListTile(
                      key: const Key('sheet-change-photo'),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textWhite,
                        child: Icon(Icons.camera_alt_outlined),
                      ),
                      title: const Text('Change profile photo'),
                      subtitle: const Text('Pick a photo from your library'),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: !saving,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _pickAndUploadProfilePic();
                      },
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
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
    }
  }

  /// Her photo (tap for the quick-edit sheet), then the change-photo button
  /// just to its right and the Messages button beside that.
  Widget _buildProfileRow() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final imageUrl = authService.currentUser?.fullProfilePicUrl;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Material(
          key: const Key('home-avatar'),
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _showQuickEditProfileSheet,
            child: _profileImage != null
                ? CircleAvatar(
                    radius: 40,
                    backgroundImage: FileImage(_profileImage!),
                  )
                : DisplayProfilePic(radius: 40, imageUrl: imageUrl),
          ),
        ),
        const SizedBox(width: 20),
        _RoundAction(
          key: const Key('home-change-photo'),
          icon: Icons.camera_alt_outlined,
          label: 'Photo',
          tooltip: 'Change profile photo',
          busy: _updatingProfilePic,
          onTap: _pickAndUploadProfilePic,
        ),
        const SizedBox(width: 20),
        TourAnchor(
          name: 'Messages',
          child: _RoundAction(
            key: const Key('home-messages'),
            icon: Icons.chat_bubble_outline,
            label: 'Messages',
            tooltip: 'Messages',
            onTap: () => context.push('/chat'),
          ),
        ),
      ],
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

/// A round brand-teal button with a one-word label under it, sized to sit
/// beside the profile photo.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: tooltip,
          child: Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: busy ? null : onTap,
              child: SizedBox(
                width: 48,
                height: 48,
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textWhite,
                        ),
                      )
                    : Icon(icon, color: AppColors.textWhite, size: 24),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}
