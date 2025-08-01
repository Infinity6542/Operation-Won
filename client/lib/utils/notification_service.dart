import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum NotificationType {
  success,
  error,
  warning,
  info,
}

class NotificationService {
  static OverlayEntry? _currentOverlay;

  static void show(
    BuildContext context, {
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
  }) {
    // Remove any existing notification
    hide();

    final overlay = Overlay.of(context);
    _currentOverlay = OverlayEntry(
      builder: (context) => _ModernNotification(
        message: message,
        type: type,
        duration: duration,
        icon: icon,
        onDismiss: hide,
      ),
    );

    overlay.insert(_currentOverlay!);
    HapticFeedback.lightImpact();
  }

  static void hide() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  // Convenience methods
  static void showSuccess(BuildContext context, String message, {IconData? icon}) {
    show(context, message: message, type: NotificationType.success, icon: icon ?? LucideIcons.check);
  }

  static void showError(BuildContext context, String message, {IconData? icon}) {
    show(context, message: message, type: NotificationType.error, icon: icon ?? LucideIcons.x);
  }

  static void showWarning(BuildContext context, String message, {IconData? icon}) {
    show(context, message: message, type: NotificationType.warning, icon: icon ?? LucideIcons.zap);
  }

  static void showInfo(BuildContext context, String message, {IconData? icon}) {
    show(context, message: message, type: NotificationType.info, icon: icon ?? LucideIcons.info);
  }
}

class _ModernNotification extends StatefulWidget {
  final String message;
  final NotificationType type;
  final Duration duration;
  final IconData? icon;
  final VoidCallback onDismiss;

  const _ModernNotification({
    required this.message,
    required this.type,
    required this.duration,
    required this.icon,
    required this.onDismiss,
  });

  @override
  State<_ModernNotification> createState() => _ModernNotificationState();
}

class _ModernNotificationState extends State<_ModernNotification>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _progressController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    // Start animations
    _slideController.forward();
    _progressController.forward();

    // Auto dismiss
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _slideController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case NotificationType.success:
        return Colors.green.shade900;
      case NotificationType.error:
        return Colors.red.shade900;
      case NotificationType.warning:
        return Colors.orange.shade900;
      case NotificationType.info:
        return Colors.blue.shade900;
    }
  }

  Color _getAccentColor() {
    switch (widget.type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.info:
        return Colors.blue;
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getAccentColor().withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        if (widget.icon != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getAccentColor().withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              widget.icon,
                              color: _getAccentColor(),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _dismiss,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              LucideIcons.x,
                              color: Colors.white.withOpacity(0.7),
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Progress indicator
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        return LinearProgressIndicator(
                          value: 1.0 - _progressController.value,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getAccentColor().withOpacity(0.5),
                          ),
                          minHeight: 3,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
