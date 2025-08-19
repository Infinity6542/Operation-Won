import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import '../comms_state.dart';
import '../utils/notification_service.dart';
import '../providers/channel_provider.dart';
import '../models/channel_model.dart';

enum PTTGestureType {
  none,
  hold,
  swipeDown,
  swipeUp,
}

class PTTGestureZone extends StatefulWidget {
  final bool enabled;
  final VoidCallback? onPermissionDenied;

  const PTTGestureZone({
    super.key,
    this.enabled = true,
    this.onPermissionDenied,
  });

  @override
  State<PTTGestureZone> createState() => _PTTGestureZoneState();
}

class _PTTGestureZoneState extends State<PTTGestureZone>
    with TickerProviderStateMixin {
  late AnimationController _holdProgressController;
  late AnimationController _countdownController;
  late AnimationController _stateTransitionController;
  late AnimationController _colorTransitionController;

  late Animation<double> _holdProgressAnimation;
  late Animation<double> _countdownAnimation;
  late Animation<double> _stateTransitionAnimation;
  late Animation<double> _colorTransitionAnimation;

  bool _isPressed = false;
  PTTGestureType _currentGesture = PTTGestureType.none;
  Offset? _startPosition;
  Offset? _currentTouchPosition;
  bool _showEmergencyCountdown = false;
  int _countdownSeconds = 3;
  bool _isStandaloneChannel = false;
  bool _isShowingLeaveDialog = false;

  final List<Offset> _velocityTracker = [];
  final List<int> _velocityTimestamps = [];
  static const double _velocityThreshold = 1000.0;

  Timer? _holdTimer;
  static const Duration _holdDuration = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();

    _holdProgressController = AnimationController(
      duration: _holdDuration,
      vsync: this,
    );

    _countdownController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _stateTransitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _colorTransitionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _holdProgressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _holdProgressController, curve: Curves.linear),
    );

    _countdownAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _countdownController, curve: Curves.linear),
    );

    _stateTransitionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _stateTransitionController, curve: Curves.easeInOut),
    );

    _colorTransitionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _colorTransitionController, curve: Curves.easeInOut),
    );

    _countdownAnimation.addListener(_onCountdownTick);
  }

  @override
  void dispose() {
    _holdProgressController.dispose();
    _countdownController.dispose();
    _stateTransitionController.dispose();
    _colorTransitionController.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onCountdownTick() {
    final newSeconds = (_countdownAnimation.value * 3).ceil();
    if (newSeconds != _countdownSeconds) {
      setState(() {
        _countdownSeconds = newSeconds;
      });

      if (newSeconds > 0) {
        HapticFeedback.lightImpact();
      }
    }
  }

  Future<void> _startPTT(CommsState commsState) async {
    if (!widget.enabled || _isPressed) return;

    final hasPermission = await commsState.checkMicrophonePermission();
    if (!hasPermission) {
      widget.onPermissionDenied?.call();
      return;
    }

    setState(() {
      _isPressed = true;
      _currentGesture = PTTGestureType.hold;
    });

    _stateTransitionController.forward();
    _colorTransitionController.forward();

    HapticFeedback.mediumImpact();

    final success = await commsState.startPTT();
    if (!success) {
      await _stopPTT(commsState);
      if (mounted) {
        NotificationService.showError(
          context,
          'Failed to start Push-to-Talk',
        );
      }
    }
  }

  Future<void> _stopPTT(CommsState commsState) async {
    if (!_isPressed) return;

    setState(() {
      _isPressed = false;
    });

    await Future.delayed(const Duration(milliseconds: 50));
    _stateTransitionController.reverse();
    _colorTransitionController.reverse();

    await commsState.stopPTT();
  }

  void _resetGestureState() {
    setState(() {
      _currentGesture = PTTGestureType.none;
      _startPosition = null;
      _currentTouchPosition = null;
      _showEmergencyCountdown = false;
      _isPressed = false;
      _isShowingLeaveDialog = false;
    });

    _velocityTracker.clear();
    _velocityTimestamps.clear();
    _holdProgressController.reset();
    _countdownController.reset();
    _stateTransitionController.reset();
    _colorTransitionController.reset();
  }

  void _handlePanStart(DragStartDetails details, CommsState commsState) {
    if (_showEmergencyCountdown) {
      _cancelEmergencyCountdown();
      return;
    }

    setState(() {
      _startPosition = details.localPosition;
      _currentTouchPosition = details.localPosition;
    });

    _velocityTracker.clear();
    _velocityTimestamps.clear();
    _holdProgressController.forward();

    _holdTimer = Timer(_holdDuration, () async {
      if (mounted && _currentGesture == PTTGestureType.none) {
        HapticFeedback.mediumImpact();
        await _startPTT(commsState);
      }
    });

    HapticFeedback.lightImpact();
  }

  void _handlePanUpdate(DragUpdateDetails details, CommsState commsState) {
    if (_startPosition == null) return;

    setState(() {
      _currentTouchPosition = details.localPosition;
    });

    final now = DateTime.now();
    final currentPosition = details.localPosition;

    _velocityTracker.add(currentPosition);
    _velocityTimestamps.add(now.millisecondsSinceEpoch);

    while (_velocityTimestamps.isNotEmpty &&
        now.millisecondsSinceEpoch - _velocityTimestamps.first > 150) {
      _velocityTracker.removeAt(0);
      _velocityTimestamps.removeAt(0);
    }

    if (_velocityTracker.length >= 3 &&
        _currentGesture == PTTGestureType.hold) {
      final oldestPosition = _velocityTracker.first;
      final oldestTime = _velocityTimestamps.first;
      final timeDelta = (now.millisecondsSinceEpoch - oldestTime) / 1000.0;

      if (timeDelta > 0) {
        final dx = currentPosition.dx - oldestPosition.dx;
        final dy = currentPosition.dy - oldestPosition.dy;
        final velocity = math.sqrt(dx * dx + dy * dy) / timeDelta;

        if (velocity > _velocityThreshold && dy.abs() > dx.abs() * 1.5) {
          if (dy < -50) {
            if (!_isStandaloneChannel) {
              _handleSwipeUp(commsState);
            }
          } else if (dy > 50) {
            _handleSwipeDown(commsState);
          }
        }
      }
    }
  }

  void _handlePanEnd(DragEndDetails details, CommsState commsState) async {
    _holdTimer?.cancel();

    if (_currentGesture == PTTGestureType.hold) {
      await _stopPTT(commsState);
      _resetGestureState();
    } else if (_currentGesture == PTTGestureType.none) {
      _resetGestureState();
    }
  }

  void _handleSwipeDown(CommsState commsState) async {
    if (_currentGesture != PTTGestureType.hold) return;

    await _stopPTT(commsState);

    setState(() {
      _currentGesture = PTTGestureType.swipeDown;
    });

    HapticFeedback.heavyImpact();
    _showLeaveChannelDialog(commsState);
  }

  void _handleSwipeUp(CommsState commsState) async {
    if (_currentGesture != PTTGestureType.hold) return;

    await _stopPTT(commsState);

    setState(() {
      _currentGesture = PTTGestureType.swipeUp;
    });

    HapticFeedback.heavyImpact();
    _startEmergencyCountdown(commsState);
  }

  void _showLeaveChannelDialog(CommsState commsState) {
    // Prevent showing multiple dialogs
    if (_isShowingLeaveDialog) return;

    _isShowingLeaveDialog = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Leave Channel'),
        content:
            const Text('Are you sure you want to leave the current channel?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetGestureState();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await commsState.leaveChannel();
              _resetGestureState();
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    ).then((_) {
      // Reset the flag when dialog is dismissed by any means
      _isShowingLeaveDialog = false;
    });
  }

  void _startEmergencyCountdown(CommsState commsState) {
    setState(() {
      _showEmergencyCountdown = true;
      _countdownSeconds = 3;
    });

    _stateTransitionController.forward();
    HapticFeedback.heavyImpact();

    _countdownController.forward().then((_) {
      if (_showEmergencyCountdown && mounted) {
        commsState.joinEmergencyChannel();
        HapticFeedback.heavyImpact();
        _resetGestureState();
      }
    });
  }

  void _cancelEmergencyCountdown() {
    _countdownController.stop();
    _countdownController.reset();
    _stateTransitionController.reverse();
    _resetGestureState();
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer2<CommsState, ChannelProvider>(
      builder: (context, commsState, channelProvider, child) {
        final canUsePTT = commsState.currentChannelId != null;

        ChannelResponse? currentChannel;
        try {
          currentChannel = channelProvider.channels.firstWhere(
            (channel) => channel.channelUuid == commsState.currentChannelId,
          );
        } catch (e) {
          currentChannel = null;
        }
        _isStandaloneChannel = currentChannel?.eventUuid == null;

        return LayoutBuilder(builder: (context, constraints) {
          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: canUsePTT
                    ? (details) => _handlePanStart(details, commsState)
                    : null,
                onPanUpdate: canUsePTT
                    ? (details) => _handlePanUpdate(details, commsState)
                    : null,
                onPanEnd: canUsePTT
                    ? (details) => _handlePanEnd(details, commsState)
                    : null,
                child: AnimatedBuilder(
                  animation: Listenable.merge(
                      [_stateTransitionAnimation, _colorTransitionAnimation]),
                  builder: (context, child) {
                    return Container(
                      width: double.infinity,
                      height: constraints.maxHeight,
                      decoration: BoxDecoration(
                        gradient:
                            _buildZoneGradient(commsState, canUsePTT, theme),
                      ),
                      child: child,
                    );
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _stateTransitionAnimation,
                            _colorTransitionAnimation
                          ]),
                          builder: (context, child) {
                            Color baseColor;
                            Color activeColor;

                            if (!canUsePTT) {
                              baseColor = activeColor =
                                  theme.colorScheme.onSurface.withAlpha(
                                      (theme.colorScheme.onSurface.alpha * 0.12)
                                          .round());
                            } else if (_currentGesture ==
                                PTTGestureType.swipeDown) {
                              baseColor = activeColor =
                                  theme.colorScheme.secondary.withAlpha(
                                      (theme.colorScheme.secondary.alpha * 0.25)
                                          .round());
                            } else {
                              baseColor = theme.colorScheme.onSurface.withAlpha(
                                  (theme.colorScheme.onSurface.alpha * 0.2)
                                      .round());
                              activeColor = theme.colorScheme.primary.withAlpha(
                                  (theme.colorScheme.primary.alpha * 0.35)
                                      .round());
                            }

                            Color dotColor = Color.lerp(
                                  baseColor,
                                  activeColor,
                                  _colorTransitionAnimation.value,
                                ) ??
                                baseColor;

                            return CustomPaint(
                              painter: _DotPatternPainter(
                                color: dotColor,
                                animationValue: _isPressed
                                    ? 0.3 +
                                        0.3 * _stateTransitionAnimation.value
                                    : 0.6 +
                                        0.4 * _stateTransitionAnimation.value,
                              ),
                            );
                          },
                        ),
                      ),
                      if (_currentTouchPosition != null &&
                          _holdProgressAnimation.value > 0)
                        Positioned(
                          left: _currentTouchPosition!.dx - 40,
                          top: _currentTouchPosition!.dy - 40,
                          child: _buildCircleProgressIndicator(theme),
                        ),
                    ],
                  ),
                ),
              ),
              if (!_isPressed && canUsePTT && !_showEmergencyCountdown)
                Positioned.fill(
                  child: Center(
                    child: IgnorePointer(
                      ignoring: true,
                      child: _buildGestureHints(_isStandaloneChannel, theme),
                    ),
                  ),
                ),
              if (_showEmergencyCountdown)
                Positioned.fill(
                  child: _buildEmergencyCountdown(theme),
                ),
            ],
          );
        });
      },
    );
  }

  Widget _buildGestureHints(bool isStandaloneChannel, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface
            .withAlpha((theme.colorScheme.surface.alpha * 0.4).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface
              .withAlpha((theme.colorScheme.onSurface.alpha * 0.15).round()),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGestureHint(
            LucideIcons.handMetal,
            'Hold anywhere to talk',
            theme,
          ),
          const SizedBox(height: 6),
          _buildGestureHint(
            LucideIcons.arrowDown,
            'Fast swipe ↓ to leave',
            theme,
          ),
          if (!isStandaloneChannel) ...[
            const SizedBox(height: 6),
            _buildGestureHint(
              LucideIcons.arrowUp,
              'Fast swipe ↑ emergency',
              theme,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGestureHint(IconData icon, String text, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurface.withAlpha(
              (((theme.colorScheme.onSurface.value >> 24) & 0xFF) * 0.7)
                  .round()),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withAlpha(
                (((theme.colorScheme.onSurface.value >> 24) & 0xFF) * 0.7)
                    .round()),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  LinearGradient _buildZoneGradient(
      CommsState commsState, bool canUsePTT, ThemeData theme) {
    Color baseGlowColor;
    Color activeGlowColor;
    double baseOpacity;

    if (!canUsePTT) {
      baseGlowColor = activeGlowColor = theme.colorScheme.onSurface;
      baseOpacity = 0.1;
    } else if (_showEmergencyCountdown ||
        _currentGesture == PTTGestureType.swipeUp) {
      baseGlowColor = activeGlowColor = theme.colorScheme.error;
      baseOpacity = 0.4;
    } else if (_currentGesture == PTTGestureType.swipeDown) {
      baseGlowColor = activeGlowColor = theme.colorScheme.secondary;
      baseOpacity = 0.35;
    } else {
      baseGlowColor = theme.colorScheme.onSurface;
      activeGlowColor = theme.colorScheme.primary;
      baseOpacity = 0.25;
    }

    final glowColor = Color.lerp(
          baseGlowColor,
          activeGlowColor,
          _colorTransitionAnimation.value,
        ) ??
        baseGlowColor;

    final animatedOpacity =
        baseOpacity * (0.5 + 0.5 * _stateTransitionAnimation.value);

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        glowColor.withValues(alpha: animatedOpacity * 0.5),
        glowColor.withValues(alpha: animatedOpacity),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  Widget _buildCircleProgressIndicator(ThemeData theme) {
    return AnimatedBuilder(
      animation: _holdProgressAnimation,
      builder: (context, child) {
        return SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surface.withValues(alpha: 0.3),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _CircleProgressPainter(
                    progress: _holdProgressAnimation.value,
                    color: theme.colorScheme.primary,
                    strokeWidth: 4,
                  ),
                ),
              ),
              Center(
                child: Icon(
                  LucideIcons.mic,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                  size: 28,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmergencyCountdown(ThemeData theme) {
    return GestureDetector(
      onTap: _cancelEmergencyCountdown,
      child: Container(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge(
                [_countdownAnimation, _stateTransitionAnimation]),
            builder: (context, child) {
              final pulseValue = 0.95 +
                  0.05 *
                      (0.5 +
                          0.5 *
                              math.sin(
                                  _countdownAnimation.value * math.pi * 6));

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Text(
                          'Emergency Mode',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Cancel',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.scale(
                            scale: pulseValue,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.error
                                    .withValues(alpha: 0.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.error
                                        .withValues(alpha: 0.4 * pulseValue),
                                    blurRadius: 40 * pulseValue,
                                    spreadRadius: 20 * pulseValue,
                                  ),
                                ],
                              ),
                              child: Icon(
                                LucideIcons.shield,
                                color: theme.colorScheme.error,
                                size: 60,
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                          Transform.scale(
                            scale: pulseValue,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.error,
                                  width: 4,
                                ),
                                color: theme.colorScheme.error
                                    .withValues(alpha: 0.1),
                              ),
                              child: Center(
                                child: Text(
                                  '$_countdownSeconds',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 72,
                                    fontWeight: FontWeight.w300,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                          Text(
                            'Emergency SOS',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 48),
                            child: Text(
                              'An emergency channel will be created and your contacts will be notified.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.8),
                                fontSize: 17,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 48),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 6,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tap anywhere to cancel',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  _DotPatternPainter({
    required this.color,
    this.animationValue = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 18.0;
    const dotRadius = 2.5;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        final dotPosition = Offset(x, y);
        final fadeFromTop = y / size.height;
        final gradientOpacity = (0.3 + 0.7 * fadeFromTop);
        final finalOpacity = gradientOpacity * animationValue;

        final paint = Paint()
          ..color = color.withAlpha((255 * finalOpacity).round())
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          dotPosition,
          dotRadius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPatternPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.animationValue != animationValue;
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _CircleProgressPainter ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
