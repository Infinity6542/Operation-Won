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
  final double heightFraction;

  const PTTGestureZone({
    super.key,
    this.enabled = true,
    this.onPermissionDenied,
    this.heightFraction = 0.4,
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

      // Haptic feedback for each second
      if (newSeconds > 0) {
        HapticFeedback.lightImpact();
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

    // Animate state transition and color change for talking
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

    // Animate state transition back and color transition to not talking
    // Ensure animations run after state change to prevent conflicts
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
    });

    _velocityTracker.clear();
    _velocityTimestamps.clear();
    _holdProgressController.reset();
    _countdownController.reset();
    _stateTransitionController.reset();
    _colorTransitionController.reset();
  }

  void _handlePanStart(DragStartDetails details, CommsState commsState) {
    // If emergency countdown is active, cancel it first
    if (_showEmergencyCountdown) {
      _cancelEmergencyCountdown();
      return; // Exit early to prevent starting a new gesture
    }

    setState(() {
      _startPosition = details.localPosition;
      _currentTouchPosition = details.localPosition;
    });

    // Clear velocity tracking
    _velocityTracker.clear();
    _velocityTimestamps.clear();

    // Start hold progress animation
    _holdProgressController.forward();

    // Start hold timer for 0.4 second delay
    _holdTimer = Timer(_holdDuration, () async {
      if (mounted && _currentGesture == PTTGestureType.none) {
        // Haptic feedback when PTT activates
        HapticFeedback.mediumImpact();
        await _startPTT(commsState);
      }
    });

    // Light haptic feedback on touch start
    HapticFeedback.lightImpact();
  }

  void _handlePanUpdate(DragUpdateDetails details, CommsState commsState) {
    if (_startPosition == null) return;

    setState(() {
      _currentTouchPosition = details.localPosition;
    });

    // Track velocity for gesture detection
    final now = DateTime.now();
    final currentPosition = details.localPosition;

    // Add current position to velocity tracker
    _velocityTracker.add(currentPosition);
    _velocityTimestamps.add(now.millisecondsSinceEpoch);

    // Keep only recent positions (last 150ms for better accuracy)
    while (_velocityTimestamps.isNotEmpty &&
        now.millisecondsSinceEpoch - _velocityTimestamps.first > 150) {
      _velocityTracker.removeAt(0);
      _velocityTimestamps.removeAt(0);
    }

    // Calculate velocity if we have enough data points and PTT is active
    if (_velocityTracker.length >= 3 &&
        _currentGesture == PTTGestureType.hold) {
      final oldestPosition = _velocityTracker.first;
      final oldestTime = _velocityTimestamps.first;
      final timeDelta = (now.millisecondsSinceEpoch - oldestTime) /
          1000.0; // Convert to seconds

      if (timeDelta > 0) {
        final dx = currentPosition.dx - oldestPosition.dx;
        final dy = currentPosition.dy - oldestPosition.dy;
        final velocity = math.sqrt(dx * dx + dy * dy) / timeDelta;

        // Check if velocity exceeds threshold and movement is primarily vertical
        if (velocity > _velocityThreshold && dy.abs() > dx.abs() * 1.5) {
          // Determine direction based on the dominant axis
          if (dy < -50) {
            // Minimum distance requirement + velocity
            // Swipe up - Emergency channel (disabled for standalone channels)
            if (!_isStandaloneChannel) {
              _handleSwipeUp(commsState);
            }
          } else if (dy > 50) {
            // Minimum distance requirement + velocity
            // Swipe down - Leave channel
            _handleSwipeDown(commsState);
          }
        }
      }
    }
  }

  void _handlePanEnd(DragEndDetails details, CommsState commsState) async {
    // Cancel hold timer if still running
    _holdTimer?.cancel();

    if (_currentGesture == PTTGestureType.hold) {
      // Normal PTT release
      await _stopPTT(commsState);
      _resetGestureState();
    } else if (_currentGesture == PTTGestureType.none) {
      // User released before hold duration completed
      _resetGestureState();
    }
    // For swipe gestures, keep the state until dialog actions complete
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
    );
  }

  void _startEmergencyCountdown(CommsState commsState) {
    setState(() {
      _showEmergencyCountdown = true;
      _countdownSeconds = 3;
    });

    // Start state transition animation for emergency mode
    _stateTransitionController.forward();

    HapticFeedback.heavyImpact();

    _countdownController.forward().then((_) {
      if (_showEmergencyCountdown && mounted) {
        // Countdown completed - activate emergency
        commsState.joinEmergencyChannel();
        HapticFeedback.heavyImpact();

        _resetGestureState();
      }
    });
  }

  void _cancelEmergencyCountdown() {
    // Stop and reset countdown
    _countdownController.stop();
    _countdownController.reset();
    _stateTransitionController.reverse();

    // Fully reset the gesture state to make zone usable again
    _resetGestureState();

    HapticFeedback.lightImpact();

    // Remove the snackbar notification for emergency cancellation
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CommsState, ChannelProvider>(
      builder: (context, commsState, channelProvider, child) {
        final canUsePTT = commsState.currentChannelId != null;

        // Check if current channel is standalone (no event)
        ChannelResponse? currentChannel;
        try {
          currentChannel = channelProvider.channels.firstWhere(
            (channel) => channel.channelUuid == commsState.currentChannelId,
          );
        } catch (e) {
          currentChannel = null;
        }
        final isStandaloneChannel = currentChannel?.eventUuid == null;

        // Update the member variable
        _isStandaloneChannel = isStandaloneChannel;

        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        final bottomPadding = MediaQuery.of(context).padding.bottom;

        // Enhanced coverage calculation for phones with rounded corners and edge-to-edge displays
        // Research shows that 60-70% coverage works best for modern phones with rounded edges
        final baseHeight =
            screenHeight * math.max(widget.heightFraction, 0.6); // Minimum 60%
        final containerHeight = baseHeight + bottomPadding;

        debugPrint(
            '[PTT] Screen: ${screenWidth}x$screenHeight, Container: ${containerHeight.toInt()} (${(containerHeight / screenHeight * 100).toInt()}%)');

        return Stack(
          children: [
            // Visual indicator when content might overlap with PTT zone
            if (canUsePTT && containerHeight > screenHeight * 0.35)
              Positioned(
                left: 0,
                right: 0,
                bottom: containerHeight -
                    50, // Show indicator near the top of PTT zone
                child: AnimatedBuilder(
                  animation: _colorTransitionAnimation,
                  builder: (context, child) {
                    return Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1.5),
                        boxShadow: [
                          BoxShadow(
                            color: (commsState.isPTTActive
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.primary)
                                .withValues(alpha: 0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            (commsState.isPTTActive
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.primary)
                                .withValues(alpha: 0.8),
                            (commsState.isPTTActive
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.primary)
                                .withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 60,
                          height: 1,
                          decoration: BoxDecoration(
                            color: (commsState.isPTTActive
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.primary)
                                .withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(0.5),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            // Main PTT Zone
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: containerHeight,
              child: Stack(
                children: [
                  // Main gesture detection area
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
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
                      animation: Listenable.merge([
                        _stateTransitionAnimation,
                        _colorTransitionAnimation
                      ]),
                      builder: (context, child) {
                        return Container(
                          width: double.infinity,
                          height: containerHeight,
                          decoration: BoxDecoration(
                            gradient: _buildZoneGradient(commsState, canUsePTT),
                          ),
                          child: child,
                        );
                      },
                      child: Stack(
                        children: [
                          // Dot matrix background with animated color transitions
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: Listenable.merge([
                                _stateTransitionAnimation,
                                _colorTransitionAnimation
                              ]),
                              builder: (context, child) {
                                // Base colors for different states
                                Color baseColor;
                                Color activeColor;

                                if (!canUsePTT) {
                                  baseColor = activeColor =
                                      Colors.white.withValues(alpha: 0.12);
                                } else if (_currentGesture ==
                                    PTTGestureType.swipeDown) {
                                  baseColor = activeColor =
                                      Colors.yellow.withValues(alpha: 0.25);
                                } else {
                                  // Default states - grey when not talking, blue when talking
                                  baseColor =
                                      Colors.grey.withValues(alpha: 0.2);
                                  activeColor =
                                      Colors.blue.withValues(alpha: 0.35);
                                }

                                // Interpolate based on color transition animation
                                // When _isPressed is true: animation goes from 0->1 (grey to blue)
                                // When _isPressed is false: animation goes from 1->0 (blue to grey)
                                Color dotColor = Color.lerp(
                                      baseColor, // Grey (when not pressed)
                                      activeColor, // Blue (when pressed)
                                      _colorTransitionAnimation.value,
                                    ) ??
                                    baseColor;

                                return CustomPaint(
                                  painter: _DotPatternPainter(
                                    color: dotColor,
                                    animationValue: _isPressed
                                        ? 0.3 +
                                            0.3 *
                                                _stateTransitionAnimation
                                                    .value // Fade out when PTT active
                                        : 0.6 +
                                            0.4 *
                                                _stateTransitionAnimation
                                                    .value, // More visible base with smooth animation
                                  ),
                                );
                              },
                            ),
                          ),

                          // Circle progress indicator at touch position (when holding)
                          if (_currentTouchPosition != null &&
                              _holdProgressAnimation.value > 0)
                            Positioned(
                              left: _currentTouchPosition!.dx -
                                  40, // Center 80px circle
                              top: _currentTouchPosition!.dy - 40,
                              child: _buildCircleProgressIndicator(),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Instructions positioned in center with lower opacity - completely non-interactive
                  if (!_isPressed && canUsePTT && !_showEmergencyCountdown)
                    Positioned.fill(
                      child: Center(
                        child: IgnorePointer(
                          ignoring:
                              true, // Explicitly ignore all pointer events
                          child: _buildGestureHints(isStandaloneChannel),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Full-screen Emergency countdown overlay (iOS/Android style)
            if (_showEmergencyCountdown)
              Positioned.fill(
                child: _buildEmergencyCountdown(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildGestureHints(bool isStandaloneChannel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            Colors.black.withValues(alpha: 0.4), // Lower opacity as requested
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15), // Lower opacity border
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
          ),
          const SizedBox(height: 6),
          _buildGestureHint(
            LucideIcons.arrowDown,
            'Fast swipe ↓ to leave',
          ),
          // Only show emergency hint for non-standalone channels
          if (!isStandaloneChannel) ...[
            const SizedBox(height: 6),
            _buildGestureHint(
              LucideIcons.arrowUp,
              'Fast swipe ↑ emergency',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGestureHint(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.white.withValues(alpha: 0.7), // Lower opacity icon
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7), // Lower opacity text
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  LinearGradient _buildZoneGradient(CommsState commsState, bool canUsePTT) {
    Color baseGlowColor;
    Color activeGlowColor;
    double baseOpacity;

    if (!canUsePTT) {
      // Grey when inactive/not in channel
      baseGlowColor = activeGlowColor = Colors.grey;
      baseOpacity = 0.2;
    } else if (_showEmergencyCountdown ||
        _currentGesture == PTTGestureType.swipeUp) {
      // Red for emergency
      baseGlowColor = activeGlowColor = Colors.red;
      baseOpacity = 0.4;
    } else if (_currentGesture == PTTGestureType.swipeDown) {
      // Yellow for leaving
      baseGlowColor = activeGlowColor = Colors.yellow;
      baseOpacity = 0.35;
    } else {
      // Default states - grey when not talking, blue when talking
      baseGlowColor = Colors.grey;
      activeGlowColor = Colors.blue;
      baseOpacity = 0.25;
    }

    // Interpolate between base and active colors using color transition animation
    // When _isPressed is true: animation goes from 0->1 (grey to blue)
    // When _isPressed is false: animation goes from 1->0 (blue back to grey)
    final glowColor = Color.lerp(
          baseGlowColor, // Grey (when not pressed)
          activeGlowColor, // Blue (when pressed)
          _colorTransitionAnimation.value,
        ) ??
        baseGlowColor;

    // Apply state transition animation to create smooth opacity changes
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
      stops: const [0.0, 0.7, 1.0],
    );
  }

  Widget _buildCircleProgressIndicator() {
    return AnimatedBuilder(
      animation: _holdProgressAnimation,
      builder: (context, child) {
        return SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            children: [
              // Background circle
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.3),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
              ),

              // Progress circle that fills around the edge
              Positioned.fill(
                child: CustomPaint(
                  painter: _CircleProgressPainter(
                    progress: _holdProgressAnimation.value,
                    color: Colors.blue,
                    strokeWidth: 4,
                  ),
                ),
              ),

              // Microphone icon in center
              Center(
                child: Icon(
                  LucideIcons.mic,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 28,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmergencyCountdown() {
    return GestureDetector(
      onTap: _cancelEmergencyCountdown,
      child: Container(
        color: Colors.black.withValues(alpha: 0.95), // Full-screen dark overlay
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge(
                [_countdownAnimation, _stateTransitionAnimation]),
            builder: (context, child) {
              // Create pulsing effect for emergency urgency (only for specific elements)
              final pulseValue = 0.95 +
                  0.05 *
                      (0.5 +
                          0.5 *
                              math.sin(
                                  _countdownAnimation.value * math.pi * 6));

              return Column(
                children: [
                  // Status bar style header (static - no pulsing)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Text(
                          'Emergency Mode',
                          style: TextStyle(
                            color: Colors.red.shade300,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main content centered
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Large emergency icon with glow effect (pulsing)
                          Transform.scale(
                            scale: pulseValue,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red.withValues(alpha: 0.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red
                                        .withValues(alpha: 0.4 * pulseValue),
                                    blurRadius: 40 * pulseValue,
                                    spreadRadius: 20 * pulseValue,
                                  ),
                                ],
                              ),
                              child: Icon(
                                LucideIcons.shield,
                                color: Colors.red.shade400,
                                size: 60,
                              ),
                            ),
                          ),

                          const SizedBox(height: 48),

                          // Large countdown number (pulsing)
                          Transform.scale(
                            scale: pulseValue,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.red.shade400,
                                  width: 4,
                                ),
                                color: Colors.red.withValues(alpha: 0.1),
                              ),
                              child: Center(
                                child: Text(
                                  '$_countdownSeconds',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 72,
                                    fontWeight: FontWeight.w300,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 48),

                          // Title and description (static - no pulsing)
                          const Text(
                            'Emergency SOS',
                            style: TextStyle(
                              color: Colors.white,
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
                                color: Colors.white.withValues(alpha: 0.8),
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

                  // Bottom section with cancel instruction (static - no pulsing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 48),
                    child: Column(
                      children: [
                        // Large slide indicator
                        Container(
                          width: 60,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'Tap anywhere to cancel',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
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
  final double animationValue; // For color transitions

  _DotPatternPainter({
    required this.color,
    this.animationValue = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 18.0; // Slightly closer spacing for more density
    const dotRadius = 2.5; // Larger dots for more prominence

    // Draw dots in a grid pattern with linear gradient from top to bottom
    // Start from 0 to cover the entire area
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        final dotPosition = Offset(x, y);

        // Linear fade from top (0) to bottom (1)
        final fadeFromTop = y / size.height;
        // Create a gentle linear gradient with minimum opacity at top
        final gradientOpacity = (0.3 +
            0.7 * fadeFromTop); // Minimum 30% opacity at top, full at bottom

        // Apply animation value for smooth color transitions
        final finalOpacity = gradientOpacity * animationValue;

        final paint = Paint()
          ..color = color.withValues(alpha: color.a * finalOpacity)
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

    // Draw the progress arc starting from top (-π/2) and going clockwise
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
