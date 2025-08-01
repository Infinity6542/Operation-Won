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
          create: (context) =>
              AuthProvider(), // Initial creation without settings
          update: (context, settingsProvider, authProvider) {
            // Only recreate if settings are loaded and current provider doesn't have settings
            if (settingsProvider.isLoaded &&
                authProvider != null &&
                authProvider.settingsProvider == null) {
              authProvider.dispose(); // Properly dispose the old one
              return AuthProvider(settingsProvider: settingsProvider);
            }
            return authProvider ??
                AuthProvider(settingsProvider: settingsProvider);
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
                background: Colors.black, // AMOLED black
                onBackground: Colors.white,
                surfaceContainer: const Color(0xFF1A1A1A),
                surfaceContainerHighest: const Color(0xFF2A2A2A),
              ),
              scaffoldBackgroundColor: Colors.black, // AMOLED black
              cardTheme: CardThemeData(
                elevation: 0,
                color: const Color(0xFF1A1A1A), // Slightly off-black
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: const Color(0xFF333333),
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
            home: AuthStateListener(
              child: const AuthenticationFlow(),
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
