import 'dart:async';
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
import 'package:operation_won/services/api_service.dart';
import 'package:operation_won/services/audio_service.dart';
import 'package:operation_won/utils/error_handler.dart';
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
class MyApp extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _audioErrorSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToAudioErrors();
    });
  }

  void _listenToAudioErrors() {
    final audioService = Provider.of<AudioService>(context, listen: false);
    _audioErrorSubscription = audioService.errorStream.listen((errorMessage) {
      EnhancedErrorHandler.showErrorSnackBar(
        context: context,
        message: 'Audio Error: $errorMessage',
      );
    });
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
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'Operation Won',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2196F3), // Material Blue
                brightness: Brightness.dark,
                primary: const Color(0xFF2196F3), // Blue primary
                secondary: const Color(0xFF4CAF50), // Green secondary
                surface: Colors.black, // AMOLED black
                onSurface: Colors.white,
                surfaceContainer: const Color(0xFF1A1A1A),
                surfaceContainerHighest: const Color(0xFF2A2A2A),
              ),
              scaffoldBackgroundColor: Colors.black, // AMOLED black
              cardTheme: const CardThemeData(
                elevation: 0,
                color: Color(0xFF1A1A1A), // Slightly off-black
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  side: BorderSide(
                    color: Color(0xFF333333),
                    width: 1,
                  ),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2196F3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
              ),
              useMaterial3: true,
            ),
            themeMode: ThemeMode.dark, // Enforce dark mode
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
