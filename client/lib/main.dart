import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:operation_won/channel.dart';
import 'package:operation_won/comms_state.dart';
import 'package:operation_won/globals/app_state.dart';
import 'package:operation_won/globals/themes.dart';
import 'package:operation_won/pages/auth_page.dart';
import 'package:operation_won/pages/home_page.dart';
import 'package:operation_won/pages/splash.dart';
import 'package:operation_won/providers/auth_provider.dart';
import 'package:operation_won/providers/channel_provider.dart';
import 'package:operation_won/providers/event_provider.dart';
import 'package:operation_won/providers/settings_provider.dart';
import 'package:operation_won/providers/theme_provider.dart';
import 'package:operation_won/services/api_service.dart';
import 'package:operation_won/services/audio_service.dart';
import 'package:operation_won/services/version_service.dart';
import 'package:operation_won/utils/error_handler.dart';
import 'package:operation_won/widgets/auth_state_listener.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final SharedPreferences sharedPrefs;

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize core services
    sharedPrefs = await SharedPreferences.getInstance();
    await VersionService.initialize();

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _audioErrorSubscription;

  @override
  void initState() {
    super.initState();
    // We need to add a post-frame callback because we can't access context
    // directly in initState to get the AudioService.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToAudioErrors();
    });
  }

  void _listenToAudioErrors() {
    // Only listen to audio errors if we have a valid context with providers
    try {
      final audioService = Provider.of<AudioService>(context, listen: false);
      _audioErrorSubscription = audioService.errorStream.listen((errorMessage) {
        EnhancedErrorHandler.showErrorSnackBar(
          context: context,
          message: 'Audio Error: $errorMessage',
        );
      });
    } catch (e) {
      debugPrint('AudioService provider not available yet: $e');
    }
  }

  @override
  void dispose() {
    _audioErrorSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppState()),
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => AudioService()),
        ProxyProvider<SettingsProvider, ApiService>(
          update: (context, settings, previous) {
            if (settings.isLoaded) {
              if (previous == null) {
                return ApiService(baseUrl: settings.apiEndpoint);
              } else {
                previous.setBaseUrl(settings.apiEndpoint);
                return previous;
              }
            }
            // Return a dummy/default while settings are loading
            return previous ??
                ApiService(
                    baseUrl:
                        SettingsProvider.predefinedEndpoints.first['api']!);
          },
          dispose: (_, apiService) {
            // Dio will be disposed automatically if that's how you've set it up
          },
        ),
        ChangeNotifierProxyProvider<SettingsProvider, CommsState>(
          create: (context) => CommsState(),
          update: (context, settingsProvider, commsState) {
            commsState ??= CommsState();
            commsState.initialize(settingsProvider);
            return commsState;
          },
        ),
        ChangeNotifierProxyProvider2<SettingsProvider, ApiService,
            AuthProvider>(
          create: (context) => AuthProvider(),
          update: (context, settingsProvider, apiService, authProvider) {
            if (settingsProvider.isLoaded) {
              return AuthProvider(
                settingsProvider: settingsProvider,
                apiService: apiService,
              );
            }
            return authProvider ?? AuthProvider();
          },
        ),
        ChangeNotifierProxyProvider2<SettingsProvider, ApiService,
            EventProvider>(
          create: (context) => EventProvider(),
          update: (context, settingsProvider, apiService, eventProvider) {
            if (settingsProvider.isLoaded) {
              return EventProvider(
                settingsProvider: settingsProvider,
                apiService: apiService,
              );
            }
            return eventProvider ?? EventProvider();
          },
        ),
        ChangeNotifierProxyProvider2<SettingsProvider, ApiService,
            ChannelProvider>(
          create: (context) => ChannelProvider(),
          update: (context, settingsProvider, apiService, channelProvider) {
            if (settingsProvider.isLoaded) {
              return ChannelProvider(
                settingsProvider: settingsProvider,
                apiService: apiService,
              );
            }
            return channelProvider ?? ChannelProvider();
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Operation Won',
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AuthStateListener(
              child: AuthenticationFlow(),
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
          return const Scaffold(
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
