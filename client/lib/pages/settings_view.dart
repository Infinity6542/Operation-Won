import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../comms_state.dart';
import '../services/state_synchronization_service.dart';
import '../widgets/ptt_gesture_guide.dart';
import '../services/permission_service.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Consumer2<AuthProvider, SettingsProvider>(
      builder: (context, authProvider, settingsProvider, child) {
        final user = authProvider.user;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Account Section
              _buildSectionHeader(context, 'Account'),
              const SizedBox(height: 12),
              _buildUserCard(context, user, authProvider),
              const SizedBox(height: 28),

              // Appearance Section
              _buildSectionHeader(context, 'Appearance'),
              const SizedBox(height: 12),
              _buildSettingsCard(context, [
                _buildDropdownSetting(
                  context,
                  title: 'Theme',
                  subtitle: 'Choose your preferred theme',
                  value: settingsProvider.themeModeName,
                  items: const [
                    DropdownMenuItem(value: 'dark', child: Text('Dark')),
                    DropdownMenuItem(value: 'light', child: Text('Light')),
                    DropdownMenuItem(
                        value: 'system', child: Text('System Default')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      settingsProvider.setThemeMode(value);
                    }
                  },
                ),
              ]),
              const SizedBox(height: 28),

              // Audio Settings Section
              _buildSectionHeader(context, 'Audio Settings'),
              const SizedBox(height: 12),
              Consumer<CommsState>(
                builder: (context, commsState, child) {
                  return _buildSettingsCard(context, [
                    _buildSwitchSetting(
                      context,
                      title: 'Magic Mic',
                      subtitle: 'Noise suppression and automatic gain control',
                      tooltip:
                          'Improves audio quality using AI-powered noise reduction and gain control. May drain battery faster when enabled.',
                      value: settingsProvider.magicMicEnabled,
                      onChanged: (value) {
                        settingsProvider.setMagicMicEnabled(value);
                      },
                    ),
                    const Divider(),
                    _buildDropdownSetting(
                      context,
                      title: 'PTT Mode',
                      subtitle: 'Push-to-talk behaviour',
                      tooltip:
                          'Hold: Press and hold to transmit\nTap: Click to toggle transmit',
                      value: settingsProvider.pttMode,
                      items: const [
                        DropdownMenuItem(value: 'hold', child: Text('Hold')),
                        DropdownMenuItem(value: 'tap', child: Text('Tap')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          settingsProvider.setPttMode(value);
                        }
                      },
                    ),
                    const Divider(),
                    _buildInfoTile(
                      context,
                      title: 'End-to-End Encryption',
                      subtitle: commsState.hasE2EEKey
                          ? '🔒 Encryption active'
                          : '🔓 No encryption key',
                      icon: commsState.hasE2EEKey
                          ? LucideIcons.lock
                          : LucideIcons.lockOpen,
                    ),
                  ]);
                },
              ),
              const SizedBox(height: 32),

              // Permissions Section
              _buildSectionHeader(context, 'Permissions'),
              const SizedBox(height: 12),
              _buildSettingsCard(context, [
                _buildActionTile(
                  context,
                  title: 'Microphone Permission',
                  subtitle: 'Required for Push-to-Talk',
                  icon: LucideIcons.mic,
                  onTap: () =>
                      PermissionService.showPermissionStatusDialog(context),
                ),
                const Divider(),
                _buildActionTile(
                  context,
                  title: 'Request All Permissions',
                  subtitle: 'Grant required permissions',
                  icon: LucideIcons.shield,
                  onTap: () async {
                    await PermissionService
                        .requestMicrophonePermissionAtStartup(context);
                  },
                ),
              ]),
              const SizedBox(height: 32),

              // About Section
              _buildSectionHeader(context, 'About'),
              const SizedBox(height: 12),
              _buildSettingsCard(context, [
                _buildActionTile(
                  context,
                  title: 'PTT Gesture Guide',
                  subtitle: 'Learn the new PTT gestures',
                  icon: LucideIcons.hand,
                  onTap: () => PTTGestureGuide.show(context),
                ),
                const Divider(),
                _buildInfoTile(
                  context,
                  title: 'Version',
                  subtitle: '1.0.0',
                  icon: LucideIcons.info,
                ),
                const Divider(),
                _buildActionTile(
                  context,
                  title: 'Privacy Policy',
                  icon: LucideIcons.shield,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Privacy Policy - Coming Soon'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  },
                ),
                const Divider(),
                _buildActionTile(
                  context,
                  title: 'Terms of Service',
                  icon: LucideIcons.fileText,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Terms of Service - Coming Soon'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 28),

              // Danger Zone
              _buildSectionHeader(context, 'Account Actions',
                  isDestructive: true),
              const SizedBox(height: 12),
              _buildDangerCard(context, authProvider),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title,
      {bool isDestructive = false}) {
    final theme = Theme.of(context);
    final color =
        isDestructive ? theme.colorScheme.error : theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(
      BuildContext context, dynamic user, AuthProvider authProvider) {
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
                        (user?.username?.isNotEmpty == true
                            ? user.username[0].toUpperCase()
                            : 'U'),
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
                          color: authProvider.isLoggedIn
                              ? Colors.green
                              : Colors.grey,
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
                        user?.username ?? 'Guest User',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${user?.username ?? 'guest'}',
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
            Wrap(
              spacing: 8.0, // gap between adjacent chips
              runSpacing: 4.0, // gap between lines
              alignment: WrapAlignment.center,
              children: [
                TextButton.icon(
                  icon: const Icon(LucideIcons.pencil, size: 16),
                  label: const Text('Edit Profile'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Edit Profile - Coming Soon'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  },
                ),
                TextButton.icon(
                  icon: const Icon(LucideIcons.lock, size: 16),
                  label: const Text('Security'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Security Settings - Coming Soon'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      child: Column(children: children),
    );
  }

  Widget _buildDangerCard(BuildContext context, AuthProvider authProvider) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.errorContainer,
      child: _buildActionTile(
        context,
        title: 'Sign Out',
        subtitle: 'Sign out of your account',
        icon: LucideIcons.logOut,
        isDestructive: true,
        onTap: () => _showSignOutDialog(context, authProvider),
      ),
    );
  }

  Widget _buildSwitchSetting(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? tooltip,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    Widget content = SwitchListTile(
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: content,
      );
    }
    return content;
  }

  Widget _buildDropdownSetting<T>(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? tooltip,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final theme = Theme.of(context);
    Widget content = ListTile(
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        underline: const SizedBox(),
        style: theme.textTheme.bodyMedium,
        dropdownColor: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: content,
      );
    }
    return content;
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: isDestructive ? theme.colorScheme.error : null,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing:
          const Icon(LucideIcons.chevronRight, color: Colors.grey, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _showSignOutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? You\'ll need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close the confirm dialog

              // Handle sign out with proper state synchronization
              await StateSynchronizationService.handleSignOut(context);
              await authProvider.logout();

              if (context.mounted) {
                // Close the settings bottom sheet
                Navigator.of(context).pop();
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Signed out successfully'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
