import 'package:flutter/material.dart';
import 'package:flutter_onboarding_slider/flutter_onboarding_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:operation_won/home.dart';

const Color textColour = Color.fromRGBO(224, 238, 249, 1.0);
const Color bgColour = Color.fromRGBO(2, 7, 11, 1.0);
const Color primaryColour = Color.fromRGBO(135, 191, 233, 1.0);
const Color secondaryColour = Color.fromRGBO(59, 26, 142, 1.0);
const Color accentColour = Color.fromRGBO(152, 52, 218, 1);

class Intro extends StatelessWidget {
  static const String id = "/intro";

  const Intro({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: OnBoard(
          'This text shouldn\'t be here! Report this to the developer.'),
    );
  }
}

class OnBoard extends StatelessWidget {
  const OnBoard(
    this.text, {
    super.key,
    this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return OnBoardingSlider(
      finishButtonText: 'Let\'s go!',
      onFinish: () async {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        // ignore: unused_local_variable
        bool seen = (prefs.getBool('seen') ?? false);
        await prefs.setBool('seen', true);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const Home(title: 'ALPHA 0.1.1'),
          ),
        );
      },
      finishButtonStyle: const FinishButtonStyle(
        backgroundColor: bgColour,
      ),
      skipTextButton: const Text(
        'Skip',
        style: TextStyle(
          fontFamily: 'Satoshi',
          fontSize: 16,
          color: primaryColour,
          fontWeight: FontWeight.w600,
        ),
      ),
      controllerColor: secondaryColour,
      totalPage: 5,
      headerBackgroundColor: bgColour,
      pageBackgroundColor: bgColour,
      background: [
        // TODO: create images for this :)
        Image.asset(
          'assets/slide_1.png',
          height: 400,
        ),
        Image.asset(
          'assets/slide_2.png',
          height: 400,
        ),
        Image.asset(
          'assets/slide_3.png',
          height: 400,
        ),
        Image.asset(
          'assets/slide_4.png',
          height: 400,
        ),
        Image.asset(
          'assets/slide_5.png',
          height: 400,
        ),
      ],
      speed: 1,
      pageBodies: [
        // Number 1
        Container(
          alignment: Alignment.center,
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: 480,
              ),
              Text(
                'Thank you for installing Operation Won!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryColour,
                  fontSize: 24.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Text(
                'Lets give you a quick introduction to the app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColour, // text colour
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Number 2
        Container(
          alignment: Alignment.center,
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: 480,
              ),
              Text(
                'In a nutshell...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryColour,
                  fontSize: 24.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Text(
                'OpWon is an open-source PPT app that works with earphones!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColour,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Number 3
        Container(
          alignment: Alignment.center,
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: 480,
              ),
              Text(
                'Pause to speak, play to listen!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryColour,
                  fontSize: 24.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Text(
                'It\'s that simple! (Just remember to resume!)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColour,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Number 4
        Container(
          alignment: Alignment.center,
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: 480,
              ),
              Text(
                'That\'s all you need for now.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryColour,
                  fontSize: 24.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Text(
                'Let\'s get started, shall we?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColour,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Number 5
        Container(
          alignment: Alignment.center,
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: 480,
              ),
              Text(
                'Well, we\'re waiting...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accentColour,
                  fontSize: 24.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
