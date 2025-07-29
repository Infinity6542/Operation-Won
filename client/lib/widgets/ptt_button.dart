import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../comms_state.dart';

class PTTButton extends StatefulWidget {
  final double size;
  final bool enabled;
  final VoidCallback? onPermissionDenied;

  const PTTButton({
    super.key,
    this.size = 80.0,
    this.enabled = true,
    this.onPermissionDenied,
  });

  @override
  State<PTTButton> createState() => _PTTButtonState();
}

class _PTTButtonState extends State<PTTButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
    });

    _animationController.repeat(reverse: true);

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
    if (!_isPressed) return;

    setState(() {
      _isPressed = false;
    });

    _animationController.stop();
    _animationController.reset();

    await commsState.stopPTT();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CommsState>(
      builder: (context, commsState, child) {
        final isConnected = commsState.isConnected;
        final hasChannel = commsState.currentChannelId != null;
        final canUsePTT = widget.enabled && isConnected && hasChannel;

        return GestureDetector(
          onTapDown: canUsePTT ? (_) => _startPTT(commsState) : null,
          onTapUp: canUsePTT ? (_) => _stopPTT(commsState) : null,
          onTapCancel: canUsePTT ? () => _stopPTT(commsState) : null,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _isPressed ? _scaleAnimation.value : 1.0,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _buildGradient(commsState, canUsePTT),
                    boxShadow: [
                      BoxShadow(
                        color: _buildShadowColor(commsState, canUsePTT),
                        blurRadius: _isPressed ? 20 : 15,
                        spreadRadius: _isPressed ? 5 : 2,
                      ),
                    ],
                    border: Border.all(
                      color: _buildBorderColor(commsState, canUsePTT),
                      width: 3,
                    ),
                  ),
                  child: _buildIcon(commsState, canUsePTT),
                ),
              );
            },
          ),
        );
      },
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

    if (_isPressed || commsState.isPTTActive) {
      return const LinearGradient(
        colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return const LinearGradient(
      colors: [Color(0xFF10B981), Color(0xFF059669)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Color _buildShadowColor(CommsState commsState, bool canUsePTT) {
    if (!canUsePTT) {
      return const Color(0xFF6B7280).withValues(alpha: 0.3);
    }

    if (_isPressed || commsState.isPTTActive) {
      return const Color(0xFFDC2626).withValues(alpha: 0.4);
    }

    return const Color(0xFF10B981).withValues(alpha: 0.3);
  }

  Color _buildBorderColor(CommsState commsState, bool canUsePTT) {
    if (!canUsePTT) {
      return const Color(0xFF9CA3AF);
    }

    if (_isPressed || commsState.isPTTActive) {
      return const Color(0xFFFEF2F2);
    }

    return const Color(0xFFECFDF5);
  }

  Widget _buildIcon(CommsState commsState, bool canUsePTT) {
    IconData iconData;
    Color iconColor;

    if (!canUsePTT) {
      iconData = LucideIcons.micOff;
      iconColor = const Color(0xFF9CA3AF);
    } else if (_isPressed || commsState.isPTTActive) {
      iconData = LucideIcons.mic;
      iconColor = Colors.white;
    } else {
      iconData = LucideIcons.mic;
      iconColor = Colors.white;
    }

    return Center(
      child: Icon(
        iconData,
        size: widget.size * 0.4,
        color: iconColor,
      ),
    );
  }
}

class PTTStatusIndicator extends StatelessWidget {
  const PTTStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CommsState>(
      builder: (context, commsState, child) {
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildStatusIcon(
                      icon: LucideIcons.wifi,
                      isActive: commsState.isConnected,
                      label: 'Connection',
                    ),
                    const SizedBox(width: 16),
                    _buildStatusIcon(
                      icon: LucideIcons.radio,
                      isActive: commsState.currentChannelId != null,
                      label: 'Channel',
                    ),
                    const SizedBox(width: 16),
                    _buildStatusIcon(
                      icon: LucideIcons.mic,
                      isActive: commsState.isPTTActive,
                      label: 'PTT',
                    ),
                  ],
                ),
                if (commsState.currentChannelId != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Channel: ${commsState.currentChannelId}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon({
    required IconData icon,
    required bool isActive,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? Colors.green : Colors.grey,
          ),
        ),
      ],
    );
  }
}
