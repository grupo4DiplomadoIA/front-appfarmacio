import 'package:iafarma/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'intro_screen.dart';


class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  _navigateToNextScreen() async {
    await Future.delayed(Duration(seconds: 3));
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool seenIntro = prefs.getBool('seenIntro') ?? false;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => seenIntro ? ChatScreen() : IntroScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 150, height: 150),
            SizedBox(height: 20),
            Text(
              'IAFarma',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}