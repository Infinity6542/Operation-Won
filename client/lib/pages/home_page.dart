import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:operation_won/home_view.dart';
import 'package:operation_won/pages/settings_view.dart';
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

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0, // Ensure settings appears below snackbars
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar for dragging
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      LucideIcons.cog,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      LucideIcons.x,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Theme.of(context).dividerColor),
            // Settings content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: const SettingsView(),
              ),
            ),
          ],
        ),
      ),
    );
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
      appBar: AppBar(
        titleSpacing: 15,
        toolbarHeight: 50,
        automaticallyImplyLeading: true,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              _showSettingsBottomSheet(context);
            },
            icon: Icon(
              LucideIcons.cog,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          )
        ],
        title: Text(
          'operation won',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
