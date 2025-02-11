import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// Define your translations as a map
const Map<String, Map<String, String>> translations = {
  'en': {
    'welcome': 'Welcome to Inspirely!',
    'splashMessage': 'Inspiring innovation every day.',
  },
  'es': {
    'welcome': '¡Bienvenido a Inspirely!',
    'splashMessage': 'Inspirando innovación todos los días.',
  },
  'it': {
    'welcome': 'Benvenuto su Inspirely!',
    'splashMessage': 'Ispirando innovazione ogni giorno.',
  },
};

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late String currentLanguage;
  late String welcomeText;
  late String splashMessage;

  @override
  void initState() {
    super.initState();
    _detectLanguage();
    _navigateToHome();
  }

  void _detectLanguage() {
    // Detect the system language
    final String systemLanguage =
        WidgetsBinding.instance.window.locale.languageCode;

    // Fallback to English if the language is not supported
    currentLanguage ='it';

    // Set translated text
    welcomeText = translations[currentLanguage]!['welcome']!;
    splashMessage = translations[currentLanguage]!['splashMessage']!;
  }

  void _navigateToHome() {
    // Navigate to the next screen after 7 seconds
    Timer(const Duration(seconds: 7), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const MyHomePage(title: 'Flutter Demo Home Page'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Display the GIF
          Center(
            child: Image.asset(
              'assets/animation.gif',
              width: 300,
              height: 500,
            ),
          ),
          const SizedBox(height: 20),
          // Display the dynamic welcome text
          Text(
            welcomeText,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          // Display the dynamic splash message
          Text(
            splashMessage,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: const Text('Welcome to the Home Page!'),
      ),
    );
  }
}