import 'package:flutter/material.dart';

/// Widget cache to prevent unnecessary widget recreations
class WidgetCache {
  static final Map<String, Widget> _cache = {};
  static const int _maxCacheSize = 50;

  /// Get or create a cached widget
  static Widget getOrCreate(String key, Widget Function() builder) {
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    // Clear oldest entries if cache is full
    if (_cache.length >= _maxCacheSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }

    final widget = builder();
    _cache[key] = widget;
    return widget;
  }

  /// Clear specific cached widget
  static void clear(String key) {
    _cache.remove(key);
  }

  /// Clear all cached widgets
  static void clearAll() {
    _cache.clear();
  }

  /// Get cache size
  static int get size => _cache.length;
}

/// Mixin for widgets that want to use caching
mixin CachedWidgetMixin<T extends StatefulWidget> on State<T> {
  final Map<String, Widget> _localCache = {};

  /// Get or create a cached widget locally
  Widget getCachedWidget(String key, Widget Function() builder) {
    if (_localCache.containsKey(key)) {
      return _localCache[key]!;
    }

    final widget = builder();
    _localCache[key] = widget;
    return widget;
  }

  /// Clear local cache
  void clearCache() {
    _localCache.clear();
  }

  @override
  void dispose() {
    clearCache();
    super.dispose();
  }
}

/// Cached stateless widget for frequently used widgets
abstract class CachedStatelessWidget extends StatelessWidget {
  const CachedStatelessWidget({super.key});

  /// Unique cache key for this widget
  String get cacheKey;

  /// Build the widget content
  Widget buildContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return WidgetCache.getOrCreate(cacheKey, () => buildContent(context));
  }
}

/// Pre-built common widgets that are frequently used
class CommonWidgets {
  static const Widget _divider = Divider();
  static const Widget _loadingIndicator = CircularProgressIndicator();
  static const Widget _emptyBox = SizedBox.shrink();

  static Widget get divider => _divider;
  static Widget get loadingIndicator => _loadingIndicator;
  static Widget get emptyBox => _emptyBox;

  static Widget sizedBox({double? width, double? height}) {
    final key = 'sizedbox_${width}_$height';
    return WidgetCache.getOrCreate(
      key,
      () => SizedBox(width: width, height: height),
    );
  }

  static Widget padding({
    required EdgeInsetsGeometry padding,
    required Widget child,
  }) {
    // Don't cache padding widgets as they contain children
    return Padding(padding: padding, child: child);
  }

  static Widget spacer({int flex = 1}) {
    final key = 'spacer_$flex';
    return WidgetCache.getOrCreate(
      key,
      () => Spacer(flex: flex),
    );
  }
}

/// Performance optimized list view with item caching
class CachedListView extends StatelessWidget {
  const CachedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.keyBuilder,
    this.scrollController,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.cacheExtent = 250.0,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final String Function(int index)? keyBuilder;
  final ScrollController? scrollController;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;
  final double cacheExtent;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: padding,
      cacheExtent: cacheExtent,
      itemCount: itemCount,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      addSemanticIndexes: true,
      itemBuilder: (context, index) {
        final widget = itemBuilder(context, index);

        // Cache the widget if keyBuilder is provided
        if (keyBuilder != null) {
          final key = keyBuilder!(index);
          return WidgetCache.getOrCreate(key, () => widget);
        }

        return RepaintBoundary(child: widget);
      },
    );
  }
}
