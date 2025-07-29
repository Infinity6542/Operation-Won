import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Performance monitoring widget for development builds
class PerformanceMonitor extends StatefulWidget {
  const PerformanceMonitor({
    super.key,
    required this.child,
    this.enabled = kDebugMode,
  });

  final Widget child;
  final bool enabled;

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  int _frameCount = 0;
  double _fps = 0.0;
  Duration _lastTimestamp = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _ticker = createTicker(_onTick);
      _ticker.start();
    }
  }

  void _onTick(Duration timestamp) {
    _frameCount++;

    if (_lastTimestamp != Duration.zero) {
      final elapsed = timestamp - _lastTimestamp;
      if (elapsed.inMilliseconds >= 1000) {
        setState(() {
          _fps = _frameCount / elapsed.inMilliseconds * 1000;
          _frameCount = 0;
          _lastTimestamp = timestamp;
        });
      }
    } else {
      _lastTimestamp = timestamp;
    }
  }

  @override
  void dispose() {
    if (widget.enabled) {
      _ticker.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _fps < 30
                  ? Colors.red
                  : _fps < 50
                      ? Colors.orange
                      : Colors.green,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'FPS: ${_fps.toStringAsFixed(1)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget rebuild tracker for performance debugging
class RebuildTracker extends StatefulWidget {
  const RebuildTracker({
    super.key,
    required this.child,
    this.name = 'Widget',
    this.enabled = kDebugMode,
  });

  final Widget child;
  final String name;
  final bool enabled;

  @override
  State<RebuildTracker> createState() => _RebuildTrackerState();
}

class _RebuildTrackerState extends State<RebuildTracker> {
  int _buildCount = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.enabled) {
      _buildCount++;
      debugPrint('${widget.name} rebuilt $_buildCount times');
    }
    return widget.child;
  }
}

/// Memory usage tracker
class MemoryTracker extends StatefulWidget {
  const MemoryTracker({
    super.key,
    required this.child,
    this.enabled = kDebugMode,
  });

  final Widget child;
  final bool enabled;

  @override
  State<MemoryTracker> createState() => _MemoryTrackerState();
}

class _MemoryTrackerState extends State<MemoryTracker> {
  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      // Monitor memory usage periodically
      _startMemoryMonitoring();
    }
  }

  void _startMemoryMonitoring() {
    Future.doWhile(() async {
      if (mounted && widget.enabled) {
        await Future.delayed(const Duration(seconds: 5));
        debugPrint(
            'Memory monitoring active (implement native bindings for actual memory stats)');
        return true;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
