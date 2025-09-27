import 'package:flutter/material.dart';
import 'package:operation_won/home_view.dart';
import 'package:operation_won/services/permission_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() {
    return _HomePageState();
  }
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  int? pageIndex = 0;
  bool _permissionRequested = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Request microphone permission when the home page is first loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissionsIfNeeded();
    });
  }

  Future<void> _requestPermissionsIfNeeded() async {
    if (_permissionRequested) return;

    _permissionRequested = true;

    try {
      final hasPermission = await PermissionService.hasMicrophonePermission();
      if (!hasPermission && mounted) {
        await PermissionService.requestMicrophonePermissionAtStartup(context);
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return const Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                    child: const HomeView(),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
