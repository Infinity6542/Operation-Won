import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../comms_state.dart';

class FloatingPTTButton extends StatefulWidget {
  final VoidCallback? onEmergencyActivated;
  
  const FloatingPTTButton({
    super.key,
    this.onEmergencyActivated,
  });

  @override
  State<FloatingPTTButton> createState() => _FloatingPTTButtonState();
}

class _FloatingPTTButtonState extends State<FloatingPTTButton>
    with TickerProviderStateMixin {
  late AnimationController _pttAnimationController;
  late AnimationController _emergencyAnimationController;
  late Animation<double> _pttScaleAnimation;
  late Animation<double> _emergencyPulseAnimation;
  
  bool _isPressed = false;
  bool _showEmergencyButton = false;

  @override
  void initState() {
    super.initState();
    
    _pttAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _emergencyAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pttScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _pttAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _emergencyPulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _emergencyAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _emergencyAnimationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pttAnimationController.dispose();
    _emergencyAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handlePTTPress(CommsState commsState) async {
    if (!commsState.isConnected || commsState.currentChannelId == null) {
      return;
    }

    final hasPermission = await commsState.checkMicrophonePermission();
    if (!hasPermission) {
      _showPermissionError();
      return;
    }

    setState(() {
      _isPressed = true;
    });

    if (commsState.isPTTToggleMode) {
      // Tap mode - toggle PTT
      await commsState.startPTT(); // This will toggle in tap mode
    } else {
      // Hold mode - start PTT
      _pttAnimationController.forward();
      await commsState.startPTT();
    }
  }

  Future<void> _handlePTTRelease(CommsState commsState) async {
    if (!_isPressed) return;

    setState(() {
      _isPressed = false;
    });

    if (!commsState.isPTTToggleMode) {
      // Hold mode - stop PTT on release
      _pttAnimationController.reverse();
      await commsState.stopPTT();
    }
    // In tap mode, PTT continues until tapped again
  }

  void _showPermissionError() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission required for Push-to-Talk'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _toggleEmergencyButton() {
    setState(() {
      _showEmergencyButton = !_showEmergencyButton;
    });
  }

  Future<void> _activateEmergency(CommsState commsState) async {
    await commsState.joinEmergencyChannel();
    widget.onEmergencyActivated?.call();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 Emergency channel activated'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CommsState>(
      builder: (context, commsState, child) {
        // Only show if user is connected and in a channel
        if (!commsState.isConnected || commsState.currentChannelId == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emergency button (shown when main button is long pressed)
              if (_showEmergencyButton) ...[
                AnimatedBuilder(
                  animation: _emergencyPulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _emergencyPulseAnimation.value,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _activateEmergency(commsState),
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                LucideIcons.triangle,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const Text(
                  'Emergency',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Main PTT Button
              Center(
                child: GestureDetector(
                  onTapDown: (_) => _handlePTTPress(commsState),
                  onTapUp: (_) => _handlePTTRelease(commsState),
                  onTapCancel: () => _handlePTTRelease(commsState),
                  onLongPressStart: (_) => _toggleEmergencyButton(),
                  onLongPressEnd: (_) => _toggleEmergencyButton(),
                  child: AnimatedBuilder(
                    animation: _pttScaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isPressed && !commsState.isPTTToggleMode 
                            ? _pttScaleAnimation.value 
                            : 1.0,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: _buildPTTGradient(commsState),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _buildPTTShadowColor(commsState),
                                blurRadius: commsState.isPTTActive ? 25 : 15,
                                spreadRadius: commsState.isPTTActive ? 8 : 3,
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            commsState.isPTTActive 
                                ? LucideIcons.mic 
                                : LucideIcons.micOff,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // PTT Mode Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  commsState.isPTTToggleMode ? 'TAP TO TOGGLE' : 'HOLD TO TALK',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // Emergency mode indicator
              if (commsState.isEmergencyMode) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.triangle,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'EMERGENCY MODE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Gradient _buildPTTGradient(CommsState commsState) {
    if (commsState.isEmergencyMode) {
      return const LinearGradient(
        colors: [Color(0xFFDC2626), Color(0xFF7F1D1D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    
    if (commsState.isPTTActive) {
      return const LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF047857)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    
    return const LinearGradient(
      colors: [Color(0xFF374151), Color(0xFF1F2937)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Color _buildPTTShadowColor(CommsState commsState) {
    if (commsState.isEmergencyMode) {
      return Colors.red.withValues(alpha: 0.4);
    }
    
    if (commsState.isPTTActive) {
      return Colors.green.withValues(alpha: 0.4);
    }
    
    return Colors.grey.withValues(alpha: 0.3);
  }
}
