import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Removed: import 'package:flutter_document_scanner/flutter_document_scanner.dart';

import 'files.dart';
import 'homepage.dart';
import 'settings.dart';

// Global app version
const String kAppVersion = "0.1.5-alpha";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load initial preferences (theme, etc.)
  final prefs = await SharedPreferences.getInstance();
  final appName = prefs.getString('appName') ?? 'HeritaScan';
  final bool isDarkTheme = prefs.getBool('isDarkTheme') ?? false;

  runApp(MyApp(
    initialAppName: appName,
    initialDarkTheme: isDarkTheme,
  ));
}

/// A custom page route that provides a gentle fade transition for a modern feel.
class FadePageRoute<T> extends PageRouteBuilder<T> {
  FadePageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) : super(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fadeIn = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            );
            return FadeTransition(
              opacity: fadeIn,
              child: child,
            );
          },
        );
}

/// SplashScreen widget that displays a logo for 3 seconds.
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  
  @override
  _SplashScreenState createState() => _SplashScreenState();
}
  
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Delay for 3 seconds then navigate to InitialScreen.
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, '/');
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Replace with your logo asset or any widget you like.
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4B9BE0), Color(0xFF98DBC6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // You can replace this Icon with your logo image (e.g., Image.asset('assets/logo.png'))
              Icon(
                Icons.camera_alt_rounded,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              const Text(
                'HeritaScan',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The root widget of the application.
class MyApp extends StatefulWidget {
  final String initialAppName;
  final bool initialDarkTheme;

  const MyApp({
    Key? key,
    required this.initialAppName,
    required this.initialDarkTheme,
  }) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();

  static Future<SharedPreferences> get prefs async =>
      SharedPreferences.getInstance();
}

class _MyAppState extends State<MyApp> {
  late String _appName;
  late bool _isDarkTheme;

  @override
  void initState() {
    super.initState();
    _appName = widget.initialAppName;
    _isDarkTheme = widget.initialDarkTheme;
  }

  /// Toggle or set the dark theme and persist it
  Future<void> setDarkTheme(bool value) async {
    setState(() {
      _isDarkTheme = value;
    });
    final prefs = await MyApp.prefs;
    await prefs.setBool('isDarkTheme', _isDarkTheme);
  }

  /// A custom on-generate-route to apply the fade transition to all page navigations
  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/splash':
        return FadePageRoute(builder: (_) => const SplashScreen());
      case '/':
        return FadePageRoute(builder: (_) => const InitialScreen());
      case '/setup':
        return FadePageRoute(builder: (_) => const SetupScreen());
      case '/main':
        return FadePageRoute(
          builder: (_) => MainScreen(
            onToggleTheme: setDarkTheme,
            isDarkTheme: _isDarkTheme,
          ),
        );
      case '/settings':
        return FadePageRoute(
          builder: (_) => SettingsScreen(
            isDarkTheme: _isDarkTheme,
            onThemeChanged: setDarkTheme,
          ),
        );
      default:
        return FadePageRoute(builder: (_) => const InitialScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Reflect the stored app name in the MaterialApp title:
      title: 'HeritaScan',

      themeMode: _isDarkTheme ? ThemeMode.dark : ThemeMode.light,

      // LIGHT THEME
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4B9BE0),
          brightness: Brightness.light,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      // DARK THEME
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4B9BE0),
          brightness: Brightness.dark,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      initialRoute: '/splash',
      onGenerateRoute: _onGenerateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// The InitialScreen checks if the necessary directories are set.
/// If not, it navigates to the SetupScreen; otherwise, it proceeds to MainScreen.
class InitialScreen extends StatefulWidget {
  const InitialScreen({Key? key}) : super(key: key);

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  Future<void> _checkSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final photosDir = prefs.getString('photosDirectory');
    final pdfsDir = prefs.getString('pdfsDirectory');

    if (photosDir == null || pdfsDir == null) {
      Navigator.pushReplacementNamed(context, '/setup');
    } else {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // You can show a simple loading screen or blank gradient.
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 7, 7, 7),
              Color.fromARGB(255, 2, 2, 2)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

/// The SetupScreen allows users to select directories for storing photos and PDFs.
class SetupScreen extends StatefulWidget {
  const SetupScreen({Key? key}) : super(key: key);

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String? _photosDirectory;
  String? _pdfsDirectory;

  Future<void> _pickDirectory(String type) async {
    final selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    setState(() {
      if (type == 'photos') {
        _photosDirectory = selectedDirectory;
      } else if (type == 'pdfs') {
        _pdfsDirectory = selectedDirectory;
      }
    });
  }

  Future<void> _saveDirectories() async {
    if (_photosDirectory == null || _pdfsDirectory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both directories.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('photosDirectory', _photosDirectory!);
    await prefs.setString('pdfsDirectory', _pdfsDirectory!);

    Navigator.pushReplacementNamed(context, '/main');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF98DBC6), Color(0xFFFFF1C1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Setup Directories'),
                backgroundColor: Colors.transparent,
                centerTitle: true,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Photos Directory
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Select Photos Directory'),
                          subtitle: Text(
                            _photosDirectory ?? 'No directory selected',
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _pickDirectory('photos'),
                            child: const Text('Choose'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // PDFs Directory
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.folder_shared),
                          title: const Text('Select PDFs Directory'),
                          subtitle: Text(
                            _pdfsDirectory ?? 'No directory selected',
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _pickDirectory('pdfs'),
                            child: const Text('Choose'),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Save Settings Button
                      ElevatedButton(
                        onPressed: _saveDirectories,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Save Settings'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The MainScreen hosts the primary functionalities of the app, including Home and Files tabs.
/// The bottom navigation bar now includes three items. The middle item is a "Take Photo" action
/// which, when tapped, triggers the photo capture without switching screens.
class MainScreen extends StatefulWidget {
  final ValueChanged<bool> onToggleTheme;
  final bool isDarkTheme;

  const MainScreen({
    Key? key,
    required this.onToggleTheme,
    required this.isDarkTheme,
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // _selectedScreenIndex: 0 for HomeScreen, 1 for FilesScreen.
  int _selectedScreenIndex = 0;
  final List<File> _photos = [];
  final List<File> _pdfs = [];
  // Removed: DocumentScannerController since flutter_document_scanner is not used.

  String? _photosDirectory;
  String? _pdfsDirectory;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDirectories().then((_) {
      _loadPhotos();
      _loadPdfs();
    });
  }

  /// Loads the directories from SharedPreferences.
  Future<void> _loadDirectories() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _photosDirectory = prefs.getString('photosDirectory');
      _pdfsDirectory = prefs.getString('pdfsDirectory');
    });
  }

  /// Saves the current list of photos to SharedPreferences.
  Future<void> _savePhotos() async {
    if (_photosDirectory == null) return;
    final prefs = await SharedPreferences.getInstance();
    final photoPaths = _photos.map((file) => file.path).toList();
    await prefs.setStringList('photos', photoPaths);
  }

  /// Loads the list of photos from SharedPreferences.
  Future<void> _loadPhotos() async {
    if (_photosDirectory == null) return;
    final prefs = await SharedPreferences.getInstance();
    final photoPaths = prefs.getStringList('photos') ?? [];
    setState(() {
      _photos.addAll(photoPaths.map((path) => File(path)));
    });
  }

  /// Saves the current list of PDFs to SharedPreferences.
  Future<void> _savePdfs() async {
    if (_pdfsDirectory == null) return;
    final prefs = await SharedPreferences.getInstance();
    final pdfPaths = _pdfs.map((file) => file.path).toList();
    await prefs.setStringList('pdfs', pdfPaths);
  }

  /// Loads the list of PDFs from SharedPreferences.
  Future<void> _loadPdfs() async {
    if (_pdfsDirectory == null) return;
    final prefs = await SharedPreferences.getInstance();
    final pdfPaths = prefs.getStringList('pdfs') ?? [];
    setState(() {
      _pdfs.addAll(pdfPaths.map((path) => File(path)));
    });
  }

  Future<void> _choosePhotoOption() async {
    final String? option = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Image source'),
          content: const Text('Would you like to upload or capture?'),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context, 'upload'),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Upload'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, 'take'),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Take new photo'),
            ),
          ],
        );
      },
    );

    if (option == 'upload') {
      await _uploadPhoto();
    } else if (option == 'take') {
      await _takeNewPhoto();
    }
  }

  /// Takes a new photo using the camera.
  Future<void> _takeNewPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? imageFile =
          await picker.pickImage(source: ImageSource.camera);

      if (imageFile == null) return;

      final Uint8List imageBytes = await imageFile.readAsBytes();

      final Directory photosDir = Directory(_photosDirectory!);
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      final String newPath =
          '${photosDir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File savedPhoto = await File(newPath).writeAsBytes(imageBytes);

      setState(() {
        _photos.add(savedPhoto);
      });
      await _savePhotos();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo taken and saved successfully!')),
      );
    } catch (e) {
      debugPrint('Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking photo: $e')),
      );
    }
  }

  /// Uploads an image from the gallery.
  Future<void> _uploadPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? imageFile =
          await picker.pickImage(source: ImageSource.gallery);

      if (imageFile == null) return;

      final Uint8List imageBytes = await imageFile.readAsBytes();

      final Directory photosDir = Directory(_photosDirectory!);
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      final String newPath =
          '${photosDir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File savedPhoto = await File(newPath).writeAsBytes(imageBytes);

      setState(() {
        _photos.add(savedPhoto);
      });
      await _savePhotos();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo uploaded and saved successfully!')),
      );
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading photo: $e')),
      );
    }
  }

  /// Import photos from the device gallery into the photos directory.
  Future<void> _importPhotos() async {
    try {
      final pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles == null || pickedFiles.isEmpty) return;

      final Directory photosDir = Directory(_photosDirectory!);
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      for (var pickedFile in pickedFiles) {
        final File oldFile = File(pickedFile.path);
        if (await oldFile.exists()) {
          final String newPath =
              '${photosDir.path}/imported_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
          final File savedPhoto = await oldFile.copy(newPath);
          setState(() => _photos.add(savedPhoto));
        }
      }

      await _savePhotos();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photos imported successfully!')),
      );
    } catch (e) {
      debugPrint('Error importing photos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing photos: $e')),
      );
    }
  }

  /// Navigation logic for the bottom navigation bar.
  /// - Index 0: Home screen.
  /// - Index 1: Take Photo action (does not change the current screen).
  /// - Index 2: Files screen.
  void _onNavIndexChanged(int newIndex) {
    if (newIndex == 1) {
      _choosePhotoOption();
      return;
    }
    setState(() {
      _selectedScreenIndex = newIndex == 0 ? 0 : 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        photos: _photos,
        onSave: _savePhotos,
        onPdfGenerated: (pdf) {
          setState(() => _pdfs.add(pdf));
          _savePdfs();
        },
        photosDirectory: _photosDirectory,
        pdfsDirectory: _pdfsDirectory,
        onImportPhotos: _importPhotos,
      ),
      FilesScreen(pdfs: _pdfs),
    ];

    int navBarSelectedIndex = _selectedScreenIndex == 0 ? 0 : 2;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.isDarkTheme
                ? [const Color(0xFF181818), const Color(0xFF434343)]
                : [
                    const Color.fromARGB(255, 198, 202, 203),
                    const Color.fromARGB(255, 234, 232, 232)
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: screens[_selectedScreenIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navBarSelectedIndex,
        onDestinationSelected: _onNavIndexChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_rounded),
            label: 'Images',
          ),
          NavigationDestination(
            icon: Icon(Icons.document_scanner_rounded),
            label: 'Photo',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_shared_rounded),
            label: 'Files',
          ),
        ],
      ),
    );
  }
}