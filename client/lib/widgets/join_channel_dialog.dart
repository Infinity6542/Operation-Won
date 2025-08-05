import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';
import '../providers/auth_provider.dart';

class JoinChannelDialog extends StatefulWidget {
  const JoinChannelDialog({super.key});

  @override
  State<JoinChannelDialog> createState() => _JoinChannelDialogState();
}

class _JoinChannelDialogState extends State<JoinChannelDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation =
        Tween<double>(begin: 0.0, end: 10.0).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _codeController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _joinChannel() async {
    if (!_formKey.currentState!.validate() || _isJoining) return;

    setState(() {
      _isJoining = true;
    });

    try {
      HapticFeedback.mediumImpact();

      final channelProvider =
          Provider.of<ChannelProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (!authProvider.isLoggedIn) {
        throw Exception('You must be logged in to join channels');
      }

      // Call the real API to join the channel
      final success =
          await channelProvider.joinChannel(_codeController.text.trim());

      if (success && mounted) {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop(true); // Return success

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Successfully joined channel!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        throw Exception('Failed to join channel');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });

        HapticFeedback.heavyImpact();
        _shakeController.forward().then((_) => _shakeController.reset());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join channel: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isSmallScreen ? double.infinity : 500,
          maxHeight: isSmallScreen ? double.infinity : 600,
        ),
        margin: EdgeInsets.all(isSmallScreen ? 16 : 32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      LucideIcons.userPlus,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Join Channel',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceContainer,
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                    ),
                  ),
                ],
              ),
            ),

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 20 : 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.info,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Enter the invite code to join an existing channel',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Invite Code Field
                      Text(
                        'Channel Invite Code *',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_shakeAnimation.value, 0),
                            child: TextFormField(
                              controller: _codeController,
                              enabled: !_isJoining,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                hintText: 'Enter invite code (e.g., ABC123)',
                                prefixIcon: const Icon(LucideIcons.ticket),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surfaceContainer,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Invite code is required';
                                }
                                if (value.trim().length < 6) {
                                  return 'Invite code must be at least 6 characters';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _joinChannel(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Info Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.lightbulb,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ask the channel admin for the invite code to join their channel',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 20 : 24),
                    ],
                  ),
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          _isJoining ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _isJoining ? null : _joinChannel,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isJoining
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(LucideIcons.userPlus),
                      label: Text(_isJoining ? 'Joining...' : 'Join Channel'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
