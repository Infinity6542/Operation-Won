import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:operation_won/home_view.dart';
import 'package:operation_won/services/permission_service.dart';

@NowaGenerated()
class HomePage extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const HomePage({super.key});

  @override
  State<HomePage> createState() {
    return _HomePageState();
  }
}

@NowaGenerated()
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
    return Scaffold(
      body: Stack(
        children: [
          const SafeArea(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 0,
              children: [
                FlexSizedBox(
                  flex: 1,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                    child: SizedBox(
                      child: HomeView(),
                    ),
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
