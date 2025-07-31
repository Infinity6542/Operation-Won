import 'package:flutter/material.dart';
import '../services/state_synchronization_service.dart';

/// Enhanced refresh indicator that uses state synchronization service
class EnhancedRefreshIndicator extends StatelessWidget {
  const EnhancedRefreshIndicator({
    super.key,
    required this.child,
    this.onRefresh,
  });

  final Widget child;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh ??
          () => StateSynchronizationService.forceRefreshAll(context),
      child: child,
    );
  }
}
