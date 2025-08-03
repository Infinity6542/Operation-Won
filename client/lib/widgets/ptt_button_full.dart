import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../comms_state.dart';

enum PTTGestureType {
  none,
  hold,
  swipeDown,
  swipeUp,
}

class EnhancedPTTButton extends StatefulWidget {
  final double size;
  final bool enabled;
  final VoidCallback? onPermissionDenied;
  final double activationZoneMultiplier;

  const EnhancedPTTButton({
    super.key,
    this.size = 80.0,
    this.enabled = true,
    this.onPermissionDenied,
    this.activationZoneMultiplier = 1.5, // Makes activation zone 50% larger
  });

  @override
  State<EnhancedPTTButton> createState() => _EnhancedPTTButtonState();
}

class _EnhancedPTTButtonState extends State<EnhancedPTTButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleAnimationController;
  late AnimationController _pulseAnimationController;
  late AnimationController _countdownController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _countdownAnimation;

  bool _isPressed = false;
  PTTGestureType _currentGesture = PTTGestureType.none;
  Offset? _startPosition;
  bool _showLeaveConfirmation = false;
  bool _showEmergencyCountdown = false;
  bool _isLeavingChannel =
      false; // Guard flag to prevent multiple leave dialogs
  int _countdownSeconds = 3;

  static const double _swipeThreshold = 50.0; // Minimum swipe distance

  @override
  void initState() {
    super.initState();

    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _countdownController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleAnimationController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));

    _countdownAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _countdownController,
      curve: Curves.linear,
    ));

    _countdownController.addListener(_onCountdownTick);
  }

  @override
  void dispose() {
    _scaleAnimationController.dispose();
    _pulseAnimationController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  void _onCountdownTick() {
    final newSeconds = (_countdownAnimation.value * 3).ceil();
    if (newSeconds != _countdownSeconds) {
      setState(() {
        _countdownSeconds = newSeconds;
      });

      // Haptic feedback for each second
      if (newSeconds > 0) {
        HapticFeedback.mediumImpact();
      }
    }
  }

  Future<void> _startPTT(CommsState commsState) async {
    if (!widget.enabled || _isPressed) return;

    // Check microphone permission first
    final hasPermission = await commsState.checkMicrophonePermission();
    if (!hasPermission) {
      widget.onPermissionDenied?.call();
      return;
    }

    setState(() {
      _isPressed = true;
      _currentGesture = PTTGestureType.hold;
    });

    _scaleAnimationController.forward();
    _pulseAnimationController.repeat(reverse: true);
    HapticFeedback.mediumImpact();

    final success = await commsState.startPTT();
    if (!success) {
      await _stopPTT(commsState);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to start Push-to-Talk'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopPTT(CommsState commsState) async {
    if (!_isPressed && _currentGesture != PTTGestureType.hold) return;

    setState(() {
      _isPressed = false;
      _currentGesture = PTTGestureType.none;
    });

    _scaleAnimationController.reverse();
    _pulseAnimationController.stop();
    _pulseAnimationController.reset();
    HapticFeedback.lightImpact();

    await commsState.stopPTT();
  }

  void _handlePanStart(DragStartDetails details, CommsState commsState) async {
    final hasChannel = commsState.currentChannelId != null;
    final canUsePTT = widget.enabled && commsState.isConnected && hasChannel;

    if (!canUsePTT) return;

    _startPosition = details.localPosition;
    await _startPTT(commsState);
  }

  void _handlePanUpdate(DragUpdateDetails details, CommsState commsState) {
    if (_startPosition == null || !_isPressed) return;

    final delta = details.localPosition - _startPosition!;
    final distance = delta.distance;

    if (distance > _swipeThreshold) {
      if (delta.dy > _swipeThreshold &&
          _currentGesture == PTTGestureType.hold) {
        // Swipe down - Leave channel
        _handleSwipeDown(commsState);
      } else if (delta.dy < -_swipeThreshold &&
          _currentGesture == PTTGestureType.hold) {
        // Swipe up - Emergency channel
        _handleSwipeUp(commsState);
      }
    }
  }

  void _handlePanEnd(DragEndDetails details, CommsState commsState) async {
    if (_currentGesture == PTTGestureType.hold) {
      await _stopPTT(commsState);
    }
    _startPosition = null;
  }

  void _handleSwipeDown(CommsState commsState) async {
    if (_currentGesture != PTTGestureType.hold) return;

    await _stopPTT(commsState);

    setState(() {
      _currentGesture = PTTGestureType.swipeDown;
      _showLeaveConfirmation = true;
    });

    HapticFeedback.heavyImpact();
    _showLeaveChannelDialog(commsState);
  }

  void _handleSwipeUp(CommsState commsState) async {
    if (_currentGesture != PTTGestureType.hold) return;

    await _stopPTT(commsState);

    setState(() {
      _currentGesture = PTTGestureType.swipeUp;
      _showEmergencyCountdown = true;
      _countdownSeconds = 3;
    });

    HapticFeedback.heavyImpact();
    _startEmergencyCountdown(commsState);
  }

  void _showLeaveChannelDialog(CommsState commsState) {
    // Prevent showing multiple dialogs
    if (_isLeavingChannel) {
      debugPrint(
          '[PTTButtonFull] Leave dialog already shown, ignoring duplicate request');
      return;
    }

    _isLeavingChannel = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(LucideIcons.logOut, color: Colors.orange),
              SizedBox(width: 8),
              Text('Leave Channel'),
            ],
          ),
          content: Text(
            'Are you sure you want to leave "${commsState.currentChannelId}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetGestureState();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await commsState.leaveChannel();
                _resetGestureState();

                if (context.mounted) {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Left channel successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    ).then((_) {
      // Reset the flag when dialog is dismissed
      _isLeavingChannel = false;
    });
  }

  void _startEmergencyCountdown(CommsState commsState) {
    _countdownController.forward();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(LucideIcons.circleAlert, color: Colors.red),
              SizedBox(width: 8),
              Text('Emergency Channel'),
            ],
          ),
          content: AnimatedBuilder(
            animation: _countdownAnimation,
            builder: (context, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Joining emergency channel in:',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.red, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        '$_countdownSeconds',
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: 1.0 - _countdownAnimation.value,
                    backgroundColor: Colors.red.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                ],
              );
            },
          ),
          actions: [
            FilledButton(
              onPressed: () {
                _countdownController.stop();
                _countdownController.reset();
                Navigator.of(context).pop();
                _resetGestureState();
                HapticFeedback.lightImpact();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.grey,
              ),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    ).then((_) {
      // Handle countdown completion
      if (_countdownController.isCompleted) {
        _joinEmergencyChannel(commsState);
      }
      _resetGestureState();
    });

    // Auto-complete after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showEmergencyCountdown) {
        Navigator.of(context).pop();
        _joinEmergencyChannel(commsState);
      }
    });
  }

  void _joinEmergencyChannel(CommsState commsState) async {
    // TODO: Implement emergency channel logic
    // This would typically join a predefined emergency channel
    HapticFeedback.heavyImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency channel feature coming soon!'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    _resetGestureState();
  }

  void _resetGestureState() {
    setState(() {
      _currentGesture = PTTGestureType.none;
      _showLeaveConfirmation = false;
      _showEmergencyCountdown = false;
      _isPressed = false;
      _isLeavingChannel = false; // Reset leave dialog flag
    });

    _countdownController.reset();
    _startPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CommsState>(
      builder: (context, commsState, child) {
        final isConnected = commsState.isConnected;
        final hasChannel = commsState.currentChannelId != null;
        final canUsePTT = widget.enabled && isConnected && hasChannel;

        // Calculate activation zone size
        final activationZoneSize =
            widget.size * widget.activationZoneMultiplier;

        return SizedBox(
          width: activationZoneSize,
          height: activationZoneSize,
          child: GestureDetector(
            onPanStart: canUsePTT
                ? (details) => _handlePanStart(details, commsState)
                : null,
            onPanUpdate: canUsePTT
                ? (details) => _handlePanUpdate(details, commsState)
                : null,
            onPanEnd: canUsePTT
                ? (details) => _handlePanEnd(details, commsState)
                : null,
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _scaleAnimationController,
                  _pulseAnimationController,
                ]),
                builder: (context, child) {
                  double scale = 1.0;
                  if (_isPressed) {
                    scale = _scaleAnimation.value;
                  }
                  if (_currentGesture == PTTGestureType.hold) {
                    scale *= _pulseAnimation.value;
                  }

                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _buildGradient(commsState, canUsePTT),
                        boxShadow: [
                          BoxShadow(
                            color: _buildShadowColor(commsState, canUsePTT),
                            blurRadius: _isPressed ? 25 : 15,
                            spreadRadius: _isPressed ? 8 : 2,
                          ),
                        ],
                        border: Border.all(
                          color: _buildBorderColor(commsState, canUsePTT),
                          width: 3,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(child: _buildIcon(commsState, canUsePTT)),
                          if (canUsePTT) _buildGestureHints(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGestureHints() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Stack(
          children: [
            // Swipe up hint
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Icon(
                  LucideIcons.arrowUp,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
            // Swipe down hint
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Icon(
                  LucideIcons.arrowDown,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Gradient _buildGradient(CommsState commsState, bool canUsePTT) {
    if (!canUsePTT) {
      return const LinearGradient(
        colors: [Color(0xFF6B7280), Color(0xFF4B5563)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    if (_currentGesture == PTTGestureType.swipeUp || _showEmergencyCountdown) {
      return const LinearGradient(
        colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    if (_currentGesture == PTTGestureType.swipeDown || _showLeaveConfirmation) {
      return const LinearGradient(
        colors: [Color(0xFFEA580C), Color(0xFFDC2626)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    if (_isPressed || commsState.isPTTActive) {
      return const LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF047857)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return const LinearGradient(
      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Color _buildShadowColor(CommsState commsState, bool canUsePTT) {
    if (!canUsePTT) return Colors.grey.withValues(alpha: 0.3);

    if (_currentGesture == PTTGestureType.swipeUp || _showEmergencyCountdown) {
      return Colors.red.withValues(alpha: 0.4);
    }

    if (_currentGesture == PTTGestureType.swipeDown || _showLeaveConfirmation) {
      return Colors.orange.withValues(alpha: 0.4);
    }

    if (_isPressed || commsState.isPTTActive) {
      return Colors.green.withValues(alpha: 0.4);
    }

    return Colors.blue.withValues(alpha: 0.3);
  }

  Color _buildBorderColor(CommsState commsState, bool canUsePTT) {
    if (!canUsePTT) return Colors.grey;

    if (_currentGesture == PTTGestureType.swipeUp || _showEmergencyCountdown) {
      return Colors.red;
    }

    if (_currentGesture == PTTGestureType.swipeDown || _showLeaveConfirmation) {
      return Colors.orange;
    }

    if (_isPressed || commsState.isPTTActive) {
      return Colors.green;
    }

    return Colors.blue;
  }

  Widget _buildIcon(CommsState commsState, bool canUsePTT) {
    IconData iconData;
    Color iconColor;

    if (!canUsePTT) {
      iconData = LucideIcons.micOff;
      iconColor = Colors.white70;
    } else if (_currentGesture == PTTGestureType.swipeUp ||
        _showEmergencyCountdown) {
      iconData = LucideIcons.circleAlert;
      iconColor = Colors.white;
    } else if (_currentGesture == PTTGestureType.swipeDown ||
        _showLeaveConfirmation) {
      iconData = LucideIcons.logOut;
      iconColor = Colors.white;
    } else if (_isPressed || commsState.isPTTActive) {
      iconData = LucideIcons.mic;
      iconColor = Colors.white;
    } else {
      iconData = LucideIcons.mic;
      iconColor = Colors.white;
    }

    return Icon(
      iconData,
      size: widget.size * 0.4,
      color: iconColor,
    );
  }
}
