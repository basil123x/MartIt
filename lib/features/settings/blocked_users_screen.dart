import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/services/moderation_service.dart';
import '../../core/utils/snackbar_helper.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = await AuthService.getCurrentUserId();
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final users = await ModerationService.blockedUsers(uid);
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(String blockedUid) async {
    final uid = await AuthService.getCurrentUserId();
    if (uid == null) return;
    await ModerationService.unblockUser(blockerUid: uid, blockedUid: blockedUid);
    var name = '';
    for (final user in _users) {
      if (user['uid']?.toString() == blockedUid) {
        name = user['name']?.toString() ?? '';
        break;
      }
    }
    BlockedSellers.instance.unblock(blockedUid, name: name);
    await _load();
    if (!mounted) return;
    showAppSnackbar(context, message: tr('moderation.unblocked'));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(title: Text(tr('moderation.blocked_users'))),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _users.isEmpty
                ? Center(child: Text(tr('moderation.no_blocked_users')))
                : ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return ListTile(
                        leading: const Icon(Iconsax.user),
                        title: Text(user['name']?.toString() ?? ''),
                        trailing: TextButton(
                          onPressed: () => _unblock(user['uid']?.toString() ?? ''),
                          child: Text(tr('moderation.unblock')),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
