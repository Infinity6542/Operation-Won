import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/event_provider.dart';

class JoinEventDialog extends StatefulWidget {
  const JoinEventDialog({super.key});

  @override
  State<JoinEventDialog> createState() => _JoinEventDialogState();
}

class _JoinEventDialogState extends State<JoinEventDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isJoining = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
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

  Future<void> _joinEvent() async {
    if (!_formKey.currentState!.validate() || _isJoining) return;

    setState(() {
      _isJoining = true;
    });

    try {
      HapticFeedback.mediumImpact();

      // Get the event provider to join the event
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final success =
          await eventProvider.joinEvent(_codeController.text.trim());

      if (success && mounted) {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop(true); // Return success

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Successfully joined event!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        throw Exception('Failed to join event');
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
            content: Text('Failed to join event: ${e.toString()}'),
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

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            math.sin(_shakeAnimation.value * math.pi * 4) * 5,
            0,
          ),
          child: AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.userPlus,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Join Event'),
              ],
            ),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter the invitation code shared by the event organiser:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _codeController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Invitation Code',
                      hintText: 'e.g., ABC123',
                      prefixIcon: const Icon(LucideIcons.key),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainer,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an invitation code';
                      }
                      if (value.trim().length < 3) {
                        return 'Code must be at least 3 characters';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _joinEvent(),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.info,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ask the event organiser for the invitation code',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    _isJoining ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: _isJoining ? null : _joinEvent,
                icon: _isJoining
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : const Icon(LucideIcons.userPlus),
                label: Text(_isJoining ? 'Joining...' : 'Join Event'),
              ),
            ],
          ),
        );
      },
    );
  }
}
