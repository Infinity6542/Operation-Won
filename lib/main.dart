// TODO: implement New Relic
// import 'package:newrelic_mobile/newrelic_mobile.dart';
import 'dart:developer' as dev;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
// import 'package:audio_service/audio_service.dart';

import 'intro.dart';
import 'home.dart';
// import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: Splash.id,
      routes: {
        Intro.id: (context) => const Intro(),
        Splash.id: (context) => const Splash(),
        Home.id: (context) => const Home(),
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
  @override
  void initState() {
    super.initState();
    checkServerStatus();
  }

  Future<http.Response> fetchAlbum() {
    return http.get(
      Uri.parse(
          'https://agora-token-server-2g0m.onrender.com/rtc/ALPHA_1/1/uid/1/?expiry=300'),
    );
  }

  checkServerStatus() async {
    final response = await fetchAlbum();
    if (response.statusCode == 200) {
      dev.log('HTTP 200');
      checkFirstSeen();
    } else {
      dev.log('HTTP${fetchAlbum()}');
      _noConnectionErr();
    }
  }

  checkFirstSeen() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool seen = (prefs.getBool('seen') ?? false);

    if (seen) {
      _handleStartScreen();
    } else {
      await prefs.setBool('seen', true);
      RDRIntro();
    }
  }

  void _handleStartScreen() async {
    Navigator.popAndPushNamed(context, Home.id);
  }

  // ignore: non_constant_identifier_names
  void RDRIntro() {
    Navigator.popAndPushNamed(context, Intro.id);
  }

  Future<void> _noConnectionErr() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Oops! Well this is awkward...'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('It looks like our servers couldn\'t be reached.'),
                const Text('Check your internet connection. bit.ly/OpWonCFoST'),
                Text('ERR_HTTP_RESPONSE_${fetchAlbum()}'),
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
        child: Image.asset('assets/e.png'),
      ),
    );
  }
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Center(
      child: Column(
        children: [
          Image.asset('assets/e.png'),
          const Text('Loading...'),
        ],
      ),
    ),
  );
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
