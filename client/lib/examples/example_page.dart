import 'package:flutter/material.dart';
import '../utils/error_handler.dart';
import '../utils/connection_test_util.dart';
import '../utils/widget_cache.dart';
import '../widgets/user_card.dart';
import '../widgets/settings_section.dart';

/// Example demonstrating how to use the new performance optimizations
class OptimizedExamplePage extends StatefulWidget {
  const OptimizedExamplePage({super.key});

  @override
  State<OptimizedExamplePage> createState() => _OptimizedExamplePageState();
}

class _OptimizedExamplePageState extends State<OptimizedExamplePage>
    with CachedWidgetMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Optimizations Example'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Example 1: Optimized User Card
            _buildSection(
              'Optimized User Card',
              'Uses Selector to only rebuild when user data changes',
              const UserCard(),
            ),

            // Example 2: Optimized Settings Section
            _buildSection(
              'Optimized Settings',
              'Each setting only rebuilds when its specific value changes',
              const SettingsSection(),
            ),

            // Example 3: Cached Widgets
            _buildSection(
              'Cached Widgets',
              'Common widgets are cached to prevent recreations',
              Column(
                children: [
                  CommonWidgets.divider,
                  CommonWidgets.sizedBox(height: 16),
                  getCachedWidget(
                    'example_button',
                    () => ElevatedButton(
                      onPressed: () => _showSuccessMessage(),
                      child: const Text('Cached Button'),
                    ),
                  ),
                ],
              ),
            ),

            // Example 4: Enhanced Error Handling
            _buildSection(
              'Enhanced Error Handling',
              'User-friendly error messages with retry options',
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () => _showErrorExample(),
                    child: const Text('Show Error Example'),
                  ),
                  CommonWidgets.sizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showSuccessExample(),
                    child: const Text('Show Success Example'),
                  ),
                ],
              ),
            ),

            // Example 5: Connection Testing
            _buildSection(
              'Optimized Connection Testing',
              'Non-blocking connection tests with proper feedback',
              ElevatedButton(
                onPressed: () => _testConnection(),
                child: const Text('Test Connection'),
              ),
            ),

            // Example 6: Cached List View
            _buildSection(
              'Cached List View',
              'Optimized list with item caching for better performance',
              SizedBox(
                height: 200,
                child: CachedListView(
                  itemCount: 50,
                  itemBuilder: (context, index) => ListTile(
                    leading: CircleAvatar(child: Text('$index')),
                    title: Text('Cached Item $index'),
                    subtitle: const Text('This item is cached for performance'),
                  ),
                  keyBuilder: (index) => 'list_item_$index',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String description, Widget content) {
    return getCachedWidget(
      'section_$title',
      () => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              CommonWidgets.sizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              CommonWidgets.sizedBox(height: 16),
              content,
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorExample() {
    EnhancedErrorHandler.showErrorSnackBar(
      context: context,
      message: 'network connection failed due to timeout',
      onRetry: () {
        EnhancedErrorHandler.showSuccessSnackBar(
          context: context,
          message: 'Retry successful!',
        );
      },
    );
  }

  void _showSuccessExample() {
    EnhancedErrorHandler.showSuccessSnackBar(
      context: context,
      message: 'Operation completed successfully!',
    );
  }

  void _showSuccessMessage() {
    EnhancedErrorHandler.showSuccessSnackBar(
      context: context,
      message: 'Cached button pressed! This widget was reused from cache.',
    );
  }

  void _testConnection() {
    ConnectionTestUtil.showConnectionTestDialog(
      context: context,
      title: 'API Connection Test',
      testFunction: () =>
          ConnectionTestUtil.testApiConnection('https://api.example.com'),
    );
  }
}

/// Example of a custom cached widget
class ExampleCachedWidget extends CachedStatelessWidget {
  const ExampleCachedWidget({super.key, required this.text});

  final String text;

  @override
  String get cacheKey => 'example_cached_widget_$text';

  @override
  Widget buildContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Cached: $text',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
