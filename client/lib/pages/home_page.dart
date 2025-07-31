import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:operation_won/home_view.dart';
import 'package:operation_won/widgets/floating_ptt_button.dart';

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

  @override
  bool get wantKeepAlive => true;

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
          // Floating PTT Button
          FloatingPTTButton(
            onEmergencyActivated: () {
              // Show emergency mode notification
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        LucideIcons.triangle,
                        color: Theme.of(context).colorScheme.onError,
                      ),
                      const SizedBox(width: 8),
                      const Text('Emergency channel activated'),
                    ],
                  ),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
