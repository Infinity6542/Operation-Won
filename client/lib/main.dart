import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:operation_won/channel.dart';
import 'package:operation_won/comms_state.dart';
import 'package:operation_won/globals/app_state.dart';
import 'package:operation_won/pages/auth_page.dart';
import 'package:operation_won/pages/home_page.dart';
import 'package:operation_won/pages/splash.dart';
import 'package:operation_won/providers/auth_provider.dart';
import 'package:operation_won/providers/channel_provider.dart';
import 'package:operation_won/providers/event_provider.dart';
import 'package:operation_won/widgets/optimized_auth_flow.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

@NowaGenerated()
late final SharedPreferences sharedPrefs;

@NowaGenerated()
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    sharedPrefs = await SharedPreferences.getInstance();
    runApp(const MyApp());
  } catch (e) {
    debugPrint('Error initializing app: $e');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Error initializing app: $e'),
        ),
      ),
    ));
  }
}

@NowaGenerated({'visibleInNowa': false})
class MyApp extends StatelessWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CommsState>(
          create: (context) => CommsState(),
          lazy: false, // Keep CommsState eager for app state
        ),
        ChangeNotifierProvider<AppState>(
          create: (context) => AppState(),
          lazy: false, // Keep AppState eager for theme
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(),
          lazy: false, // Keep AuthProvider eager for authentication flow
        ),
        ChangeNotifierProvider<EventProvider>(
          create: (context) => EventProvider(),
          lazy: true, // Load only when needed
        ),
        ChangeNotifierProvider<ChannelProvider>(
          create: (context) => ChannelProvider(),
          lazy: true, // Load only when needed
        ),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          debugPrint('App State loaded: ${appState.theme}');

          return MaterialApp(
            title: 'Operation Won',
            debugShowCheckedModeBanner: false,
            theme: appState.theme,
            home: const OptimizedAuthenticationFlow(),
            routes: {
              'Channel': (context) => const Channel(),
              'AuthPage': (context) => const AuthPage(),
              'HomePage': (context) => const HomePage(),
              'Splash': (context) => const Splash(),
            },
          );
        },
      ),
    );
  }
}

class AuthenticationFlow extends StatelessWidget {
  const AuthenticationFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        debugPrint(
            'AuthenticationFlow: isLoading=${authProvider.isLoading}, isLoggedIn=${authProvider.isLoggedIn}, error=${authProvider.error}');

        // Show error if there's one
        if (authProvider.error != null) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.circleAlert,
                        color: Theme.of(context).colorScheme.error,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Connection Error',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        authProvider.error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () {
                          authProvider.clearError();
                        },
                        icon: const Icon(LucideIcons.refreshCw),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Show loading screen while initializing
        if (authProvider.isLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xff59dafb),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        }

        // Show home page if logged in
        if (authProvider.isLoggedIn) {
          return const HomePage();
        }

        // Show auth page if not logged in
        return const AuthPage();
      },
    );
  }
}
