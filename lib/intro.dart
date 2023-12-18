import 'package:flutter/material.dart';
import 'package:flutter_onboarding_slider/flutter_onboarding_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:operation_won/home.dart';

const Color textColour = Color.fromRGBO(224, 238, 249, 1.0);
const Color bgColour = Color.fromRGBO(2, 7, 11, 1.0);
const Color primaryColour = Color.fromRGBO(135, 191, 233, 1.0);
const Color secondaryColour = Color.fromRGBO(59, 26, 142, 1.0);
const Color accentColour = Color.fromRGBO(152, 52, 218, 1.0);

class Intro extends StatelessWidget {
  static const String id = "/intro";

  const Intro({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: OnBoard(
          'this text shouldn\'t be here! Report this to the developer.'),
    );
  }
}

class OnBoard extends StatelessWidget {
  const OnBoard(
    this.text, {
    super.key,
    this.gradient = const LinearGradient(colors: [
      Colors.white,
      Colors.white,
    ]),
    this.style,
  });

  final String text;
  final TextStyle? style;
  final Gradient gradient;
  final Color kDarkBlueColor = const Color(0xFF053149);

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: OnBoardingSlider(
        finishButtonText: 'Let\'s go!',
        onFinish: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const Home(),
            ),
          );
        },
        finishButtonStyle: FinishButtonStyle(
          backgroundColor: kDarkBlueColor,
        ),
        skipTextButton: Text(
          'Skip',
          style: TextStyle(
            fontSize: 16,
            color: kDarkBlueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        controllerColor: kDarkBlueColor,
        totalPage: 3,
        headerBackgroundColor: Colors.black,
        pageBackgroundColor: Colors.black,
        background: [
          Image.asset(
            'assets/e.png',
            height: 400,
          ),
          // TODO: create images for this :)
          Image.asset(
            'assets/slide_2.png',
            height: 400,
          ),
          Image.asset(
            'assets/slide_3.png',
            height: 400,
          ),
          Image.asset(
            'asset link here',
            height: 400,
          )
        ],
        speed: 1.8,
        pageBodies: [
          // Number 1
          Container(
            alignment: Alignment.center,
            width: MediaQuery.of(context).size.width,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(
                  height: 480,
                ),
                Text(
                  'Thank you for installing Operation Won!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: <Color>[
                          primaryColour,
                          accentColour,
                        ],
                      ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0,
                          100.0)), // accent colour (gradient possibly?)
                    fontSize: 24.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                const Text(
                  'Lets give you a quick introduction to the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white, // text colour
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(
                  height: 480,
                ),
                Text(
                  'In a nutshell,',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kDarkBlueColor,
                    fontSize: 24.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                const Text(
                  'OpWon is an open-source PPT app that works with earphones!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black26,
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(
                  height: 480,
                ),
                Text(
                  'Pause to speak, play to listen!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kDarkBlueColor,
                    fontSize: 24.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                const Text(
                  'It\'s that simple! (Just remember to resume!)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black26,
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(
                  height: 480,
                ),
                Text(
                  'That\'s all you need for now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kDarkBlueColor,
                    fontSize: 24.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                const Text(
                  'Let\'s get started, shall we?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black26,
                    fontSize: 18.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            alignment: Alignment.center,
            width: MediaQuery.of(context).size.width,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(
                  height: 480,
                ),
                Text(
                  'Well, we\'re waiting...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kDarkBlueColor,
                    fontSize: 24.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
