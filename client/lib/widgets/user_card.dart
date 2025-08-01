import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class UserCard extends StatelessWidget {
  const UserCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AuthProvider, _UserData>(
      selector: (context, authProvider) => _UserData(
        username: authProvider.user?.username,
        isLoggedIn: authProvider.isLoggedIn,
      ),
      builder: (context, userData, child) {
        return _UserCardContent(userData: userData);
      },
    );
  }
}

/// Immutable user data class for better performance
class _UserData {
  const _UserData({
    required this.username,
    required this.isLoggedIn,
  });

  final String? username;
  final bool isLoggedIn;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UserData &&
          runtimeType == other.runtimeType &&
          username == other.username &&
          isLoggedIn == other.isLoggedIn;

  @override
  int get hashCode => username.hashCode ^ isLoggedIn.hashCode;
}

/// The actual user card content widget
class _UserCardContent extends StatelessWidget {
  const _UserCardContent({required this.userData});

  final _UserData userData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        _getInitial(userData.username),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color:
                              userData.isLoggedIn ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userData.username ?? 'Guest User',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${userData.username ?? 'guest'}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _UserActionButtons(),
          ],
        ),
      ),
    );
  }

  String _getInitial(String? username) {
    if (username?.isNotEmpty == true) {
      return username![0].toUpperCase();
    }
    return 'U';
  }
}

/// Static action buttons that don't need to rebuild
class _UserActionButtons extends StatelessWidget {
  const _UserActionButtons();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      alignment: WrapAlignment.center,
      children: [
        TextButton.icon(
          icon: const Icon(LucideIcons.pencil, size: 16),
          label: const Text('Edit Profile'),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Edit Profile - Coming Soon')),
            );
          },
        ),
        TextButton.icon(
          icon: const Icon(LucideIcons.lock, size: 16),
          label: const Text('Security'),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Security Settings - Coming Soon')),
            );
          },
        ),
      ],
    );
  }
}
