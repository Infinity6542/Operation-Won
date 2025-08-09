import 'dart:async' as async_timer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Mixin to help with performance optimizations
mixin PerformanceOptimizationMixin<T extends StatefulWidget> on State<T> {
  /// Debounce timer for reducing rebuild frequency
  async_timer.Timer? _debounceTimer;

  /// Debounced setState - reduces unnecessary rebuilds
  void debouncedSetState(VoidCallback fn,
      {Duration delay = const Duration(milliseconds: 16)}) {
    _debounceTimer?.cancel();
    _debounceTimer = async_timer.Timer(delay, () {
      if (mounted) {
        setState(fn);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Optimized Consumer widget that only rebuilds when specific fields change
class OptimizedConsumer<T extends ChangeNotifier, R> extends StatelessWidget {
  const OptimizedConsumer({
    super.key,
    required this.selector,
    required this.builder,
    this.child,
  });

  final R Function(BuildContext context, T value) selector;
  final Widget Function(BuildContext context, R value, Widget? child) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Selector<T, R>(
      selector: (context, provider) => selector(context, provider),
      builder: builder,
      child: child,
    );
  }
}

/// Const widget wrapper to ensure maximum reusability
class ConstWidgetWrapper extends StatelessWidget {
  const ConstWidgetWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Performance-optimized list view with automatic keep-alive
class OptimizedListView extends StatelessWidget {
  const OptimizedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.scrollController,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final ScrollController? scrollController;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: padding,
      itemCount: itemCount,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      addSemanticIndexes: true,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: itemBuilder(context, index),
        );
      },
    );
  }
}

/// Memoized widget builder to prevent unnecessary rebuilds
class MemoizedWidget extends StatelessWidget {
  const MemoizedWidget({
    super.key,
    required this.builder,
    required this.dependencies,
  });

  final Widget Function() builder;
  final List<Object?> dependencies;

  @override
  Widget build(BuildContext context) {
    return _MemoizedWidgetImpl(
      builder: builder,
      dependencies: dependencies,
    );
  }
}

class _MemoizedWidgetImpl extends StatefulWidget {
  const _MemoizedWidgetImpl({
    required this.builder,
    required this.dependencies,
  });

  final Widget Function() builder;
  final List<Object?> dependencies;

  @override
  State<_MemoizedWidgetImpl> createState() => _MemoizedWidgetImplState();
}

class _MemoizedWidgetImplState extends State<_MemoizedWidgetImpl> {
  Widget? _cachedWidget;
  List<Object?>? _lastDependencies;

  @override
  Widget build(BuildContext context) {
    if (_cachedWidget == null ||
        !listEquals(_lastDependencies, widget.dependencies)) {
      _cachedWidget = widget.builder();
      _lastDependencies = List.from(widget.dependencies);
    }
    return _cachedWidget!;
  }
}
