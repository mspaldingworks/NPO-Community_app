import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/friend_service.dart';
import 'package:transconnect/core/services/chat_service.dart';
import 'package:transconnect/models/user.dart';
import 'package:transconnect/theme/app_theme.dart';
import 'package:transconnect/widgets/loading_indicator.dart';
import 'package:transconnect/widgets/display_profile_pic.dart';

class CreateConversationScreen extends StatefulWidget {
  const CreateConversationScreen({super.key});

  @override
  State<CreateConversationScreen> createState() => _CreateConversationScreenState();
}

class _CreateConversationScreenState extends State<CreateConversationScreen> with SingleTickerProviderStateMixin {
  final FriendService _friendService = FriendService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  List<Friend> _searchResults = [];
  List<Friend> _selectedUsers = [];
  List<Friend> _friends = [];
  bool _isLoading = false;
  bool _isFriendsLoading = true;
  String? _friendsError;
  bool _isCreatingGroup = false;
  Timer? _debounce;
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isFriendsLoading = true;
      _friendsError = null;
    });

    try {
      final results = await _friendService.listFriends();
      if (!mounted) return;
      setState(() {
        _friends = results;
        _isFriendsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _friendsError = 'Failed to load friends. Please try again.';
        _isFriendsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _groupNameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _searchUsers(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        if (mounted) {
          setState(() {
            _searchResults = [];
          });
        }
        return;
      }
      
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      
      try {
        final results = await _friendService.searchFriends(query);
        if (mounted) {
          setState(() {
            // Filter out already selected users and current user
            final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.id;
            _searchResults = results.where((user) {
              return !_selectedUsers.any((selected) => selected.id == user.id) &&
                  user.id != currentUserId;
            }).toList();
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to search users')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
  }

  void _toggleUserSelection(Friend user) {
    setState(() {
      if (_selectedUsers.contains(user)) {
        _selectedUsers.remove(user);
      } else {
        _selectedUsers.add(user);
      }
      // Clear search results when user is selected
      _searchController.clear();
      _searchResults = [];
    });
  }

  Future<void> _createDirectChat(Friend user) async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      // COMMENTED OUT
      // final conversations = await _chatService.getAllConversations();
      // final existingConversation = conversations.firstWhere(
      //   (conv) => !conv.isGroup &&
      //       conv.participants.any((p) => p.id == user.id),
      //   orElse: () => Conversation(
      //     id: '',
      //     participants: const [],
      //     lastMessage: null,
      //     unreadCount: 0,
      //     isGroup: false,
      //     createdAt: DateTime.now(),
      //     updatedAt: DateTime.now(),
      //   ),
      // );

      // if (existingConversation.id.isNotEmpty) {
      //   if (mounted) {
      //     GoRouter.of(context).pop();
      //     GoRouter.of(context).push(
      //       '/chat/${existingConversation.id}',
      //       extra: existingConversation,
      //     );
      //   }
      //   return;
      // }

      // final conversation = await _chatService.createChat(
      //   participantIds: [user.id.toString()],
      // );

      // if (mounted) {
      //   GoRouter.of(context).pop();
      //   GoRouter.of(context).push(
      //     '/chat/${conversation.id}',
      //     extra: conversation,
      //   );
      // }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start conversation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _createGroupChat() async {
    if (_isLoading || _selectedUsers.length < 2) return;
    if (_isCreatingGroup && !_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // final participantIds = _selectedUsers.map((u) => u.id.toString()).toList();
      // final groupName = _groupNameController.text.trim().isNotEmpty 
      //     ? _groupNameController.text.trim()
      //     : '${_selectedUsers.take(2).map((u) => u.username.split(' ').first).join(', ')}${_selectedUsers.length > 2 ? ' +${_selectedUsers.length - 2}' : ''}';
      
      // final conversation = await _chatService.createGroupChat(
      //   name: groupName,
      //   participantIds: participantIds,
      // );

      // if (mounted) {
      //   GoRouter.of(context).pop();
      //   GoRouter.of(context).push(
      //     '/chat/${conversation.id}',
      //     extra: conversation,
      //   );
      // }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _toggleGroupMode() {
    setState(() {
      _isCreatingGroup = !_isCreatingGroup;
      if (!_isCreatingGroup) {
        _selectedUsers.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isCreatingGroup 
            ? Text('New Group (${_selectedUsers.length})')
            : const Text('New Chat'),
        actions: [
          if (_isCreatingGroup && _selectedUsers.isNotEmpty)
            TextButton(
              onPressed: _selectedUsers.length < 2 ? null : _createGroupChat,
              child: Text(
                'Create',
                style: TextStyle(
                  color: _selectedUsers.length < 2 
                      ? Colors.grey 
                      : Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Contacts'),
            Tab(icon: Icon(Icons.group), text: 'New Group'),
          ],
          onTap: (index) {
            setState(() {
              _isCreatingGroup = index == 1;
              if (!_isCreatingGroup) {
                _selectedUsers.clear();
              }
            });
          },
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: _isCreatingGroup 
                    ? 'Search for people to add...'
                    : 'Search for a user...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              onChanged: _searchUsers,
            ),
          ),
          
          // Selected users (for group chat)
          if (_isCreatingGroup && _selectedUsers.isNotEmpty) ..._buildSelectedUsers(),
          
          // Group name input (for group chat)
          if (_isCreatingGroup && _selectedUsers.isNotEmpty) ..._buildGroupNameInput(),
          
          // Search results or friend list
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingIndicator())
                : _isFriendsLoading
                    ? const Center(child: LoadingIndicator())
                    : _friendsError != null
                        ? _buildFriendsError()
                : _searchController.text.isNotEmpty
                    ? _buildSearchResults()
                    : _isCreatingGroup
                        ? _buildGroupCreationGuide()
                        : _buildContactsList(),
          ),
        ],
      ),
    );
  }
  
  List<Widget> _buildSelectedUsers() {
    return [
      SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _selectedUsers.length,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          itemBuilder: (context, index) {
            final user = _selectedUsers[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                children: [
                  Stack(
                    children: [
                      DisplayProfilePic(radius: 32, imageUrl: user.fullProfilePicUrl),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => _toggleUserSelection(user),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 16, color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 64,
                    child: Text(
                      user.username.split(' ')[0],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      const Divider(height: 1),
    ];
  }
  
  List<Widget> _buildGroupNameInput() {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _groupNameController,
            decoration: InputDecoration(
              hintText: 'Group name (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            validator: (value) {
              if (value != null && value.length > 30) {
                return 'Group name is too long';
              }
              return null;
            },
          ),
        ),
      ),
      const Divider(height: 1),
    ];
  }
  
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text('No users found'),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: DisplayProfilePic(radius: 20, imageUrl: user.fullProfilePicUrl),
          title: Text(user.username),
          onTap: _isCreatingGroup
              ? () => _toggleUserSelection(user)
              : () => _createDirectChat(user),
          trailing: _isCreatingGroup
              ? Checkbox(
                  value: _selectedUsers.contains(user),
                  onChanged: (_) => _toggleUserSelection(user),
                )
              : null,
        );
      },
    );
  }

  Widget _buildContactsList() {
    Widget buildNewGroupTile() {
      return ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.group_add),
        ),
        title: const Text('New Group'),
        onTap: () {
          setState(() {
            _isCreatingGroup = true;
            _tabController.animateTo(1);
          });
        },
      );
    }

    if (_friends.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFriends,
        child: ListView(
          children: [
            buildNewGroupTile(),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No friends yet',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: ListView.separated(
        itemCount: _friends.length + 2,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == 0) {
            return buildNewGroupTile();
          }
          if (index == 1) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
              child: Text(
                'Your friends',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            );
          }

          final friend = _friends[index - 2];
          return ListTile(
            leading: DisplayProfilePic(radius: 20, imageUrl: friend.fullProfilePicUrl),
            title: Text(friend.username),
            subtitle: friend.statusMessage != null && friend.statusMessage!.isNotEmpty
                ? Text(friend.statusMessage!, maxLines: 1, overflow: TextOverflow.ellipsis)
                : (friend.city != null && friend.city!.isNotEmpty
                    ? Text(friend.city!)
                    : null),
            onTap: () => _createDirectChat(friend),
          );
        },
      ),
    );
  }

  Widget _buildGroupCreationGuide() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_add,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Create a new group',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Search for people to add to your group',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_selectedUsers.isNotEmpty) ...[
            const Text(
              'Selected participants:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: _selectedUsers.map((user) {
                return Chip(
                  label: Text(user.username.split(' ')[0]),
                  onDeleted: () => _toggleUserSelection(user),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (_selectedUsers.length >= 2)
              ElevatedButton(
                onPressed: _createGroupChat,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Create Group'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFriendsError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_friendsError ?? 'Something went wrong'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadFriends,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}