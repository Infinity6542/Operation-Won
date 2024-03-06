import 'dart:developer' as dev;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
// import 'package:audio_service/audio_service.dart';
import 'intro.dart';
import 'home.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
// import 'package:sentry/sentry.dart';

void main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://7de0b9e68b40692d64698e019b0a4e32@o4506426503135232.ingest.sentry.io/4506426513620992';
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => runApp(const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Operation Won',
      theme: ThemeData(
        useMaterial3: true,
      ),
      initialRoute: Splash.id,
      routes: {
        Intro.id: (context) => const Intro(),
        Splash.id: (context) => const Splash(),
        Home.id: (context) => const Home(title: 'ALPHA 0.1.1'),
        Config.id: (context) => const Config(title: 'Settings'),
      },
    );
  }
}

class Splash extends StatefulWidget {
  static const String id = "/splash";
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  double? bodyTextSize = 24;
  @override
  void initState() {
    super.initState();
    afterFirstLayout(context);
  }

  Future<void> checkServerStatus() async {
    http.Response response = await http
        .get(Uri.parse('https://agora-token-server-2g0m.onrender.com/'));
    if (response.statusCode < 200 || response.statusCode > 299) {
      print(
          '[DEBUG] [SERVER] Server status code ${response.statusCode.toString()}');
      _noConnectionErr();
    } else {
      // Check if the user has gone through onboarding
      checkFirstSeen();
    }
  }

  checkFirstSeen() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool seen = (prefs.getBool('seen') ?? false);

    if (seen) {
      _handleStartScreen();
    } else {
      RDRIntro();
    }
  }

  Future<void> _handleStartScreen() async {
    Navigator.popAndPushNamed(context, Home.id);
  }

  // ignore: non_constant_identifier_names
  Future<void> RDRIntro() async {
    Navigator.popAndPushNamed(context, Intro.id);
  }

  Future<void> _noConnectionErr() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Well this is awkward...'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text(
                  'It looks like our servers couldn\'t be reached.',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                  ),
                ),
                const Text(
                  'Check your internet connection. bit.ly/OpWonCFoSU',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                  ),
                ),
                Text(
                    'ERR_HTTP_RESPONSE_${http.get(Uri.parse('https://agora-token-server-2g0m.onrender.com/rtc/ALPHA_1/1/uid/1/?expiry=300'))}'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Dismiss'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // After the app is built
  void afterFirstLayout(BuildContext context) => checkServerStatus();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/entire_e.png"),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class Config extends StatefulWidget {
  static const String id = "/Config";
  const Config({super.key, required this.title});

  final String title;

  @override
  State<Config> createState() => _ConfigState();
}

class _ConfigState extends State<Config> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        // TODO: build children w/ dropdown menu options and customiation (?)
      ),
    );
  }
}
