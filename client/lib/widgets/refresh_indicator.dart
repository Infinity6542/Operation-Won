import 'package:flutter/material.dart';
import '../services/state_synchronization_service.dart';

class CustomRefreshIndicator extends StatelessWidget {
  const CustomRefreshIndicator({
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
