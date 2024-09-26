import 'package:iafarma/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IntroScreen extends StatelessWidget {
  final List<PageViewModel> pages = [
    PageViewModel(
      title: "Bienvenido a IAFarma",
      body: "Tu asistente personal para consultas sobre Fármacos en base a Vademecum.",
      image: _buildImage("assets/images/intro1.png"),
      decoration: _getPageDecoration(),
    ),
    PageViewModel(
      title: "Consulta sobre Medicamentos",
      body: "Obtén información detallada sobre fármacos y sus usos.",
      image: _buildImage("assets/images/intro2.jpg"),
      decoration: _getPageDecoration(),
    ),
    PageViewModel(
      title: "Encuentra Farmacias Cercanas",
      body: "Localiza las farmacias más cercanas a tu ubicación. Además de recomendaciones de profesionales Médicos en tu área.",
      image: _buildImage("assets/images/intro3.jpg"),
      decoration: _getPageDecoration(),
    ),
  ];

  static Widget _buildImage(String assetName) {
    return Padding(
      padding: const EdgeInsets.only(top: 100.0),
      child: Image.asset(assetName, height: 250.0),
    );
  }

  static PageDecoration _getPageDecoration() {
    return PageDecoration(
      titleTextStyle: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold),
      bodyTextStyle: TextStyle(fontSize: 18.0),
      bodyPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Colors.white,
      imagePadding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      pages: pages,
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context),
      showSkipButton: true,
      skip: const Text("Saltar"),
      done: const Text("Listo", style: TextStyle(fontWeight: FontWeight.w600)),
      next: const Icon(Icons.arrow_forward),
      dotsDecorator: DotsDecorator(
        size: const Size.square(10.0),
        activeSize: const Size(20.0, 10.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
    );
  }

  void _onIntroEnd(context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenIntro', true);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ChatScreen()),
    );
  }
}