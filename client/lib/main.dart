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
import 'package:operation_won/providers/settings_provider.dart';
import 'package:operation_won/widgets/optimized_auth_flow.dart';
import 'package:operation_won/widgets/auth_state_listener.dart';
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
        ChangeNotifierProvider(create: (context) => AppState()),
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
        ChangeNotifierProxyProvider<SettingsProvider, CommsState>(
          create: (context) => CommsState(),
          update: (context, settingsProvider, commsState) {
            commsState ??= CommsState();
            commsState.initialize(settingsProvider);
            return commsState;
          },
        ),
        ChangeNotifierProxyProvider<SettingsProvider, AuthProvider>(
          create: (context) => AuthProvider(),
          update: (context, settingsProvider, authProvider) {
            if (authProvider == null) {
              return AuthProvider(settingsProvider: settingsProvider);
            }
            return authProvider;
          },
        ),
        ChangeNotifierProxyProvider<SettingsProvider, EventProvider>(
          create: (context) => EventProvider(),
          update: (context, settingsProvider, eventProvider) {
            if (eventProvider == null) {
              return EventProvider(settingsProvider: settingsProvider);
            }
            return eventProvider;
          },
        ),
        ChangeNotifierProxyProvider<SettingsProvider, ChannelProvider>(
          create: (context) => ChannelProvider(),
          update: (context, settingsProvider, channelProvider) {
            if (channelProvider == null) {
              return ChannelProvider(settingsProvider: settingsProvider);
            }
            return channelProvider;
          },
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'Operation Won',
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0D47A1), // Deep Blue
                brightness: Brightness.light,
                secondary: const Color(0xFF4CAF50), // Green
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0D47A1), // Deep Blue
                brightness: Brightness.dark,
                primary:
                    const Color(0xFF42A5F5), // Lighter Blue for readability
                secondary: const Color(0xFF66BB6A), // Green
                background: Colors.black,
                surface: const Color(0xFF121212), // Very dark grey for cards
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                onBackground: Colors.white,
                onSurface: Colors.white,
              ),
            ),
            themeMode: settings.themeMode,
            home: AuthStateListener(
              child: const OptimizedAuthenticationFlow(),
            ),
            routes: {
              'Channel': (context) => const Channel(),
              'AuthPage': (context) => const AuthPage(),
              'HomePage': (context) => const HomePage(),
              'Splash': (context) => const Splash(),
            },
            debugShowCheckedModeBanner: false,
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
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading...',
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
