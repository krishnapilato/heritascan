import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'files.dart';
// Import screens from separate files
import 'homepage.dart';
import 'settings.dart';

// Global app version
const String kAppVersion = "0.1.5-alpha";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load initial preferences (app name, theme, etc.)
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

  // Helper to read preferences anywhere
  static Future<SharedPreferences> get prefs async =>
      await SharedPreferences.getInstance();
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

  /// Update the app name and persist it
  Future<void> setAppName(String newName) async {
    setState(() {
      _appName = newName.trim().isEmpty ? 'HeritaScan' : newName;
    });
    final prefs = await MyApp.prefs;
    await prefs.setString('appName', _appName);
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
      case '/':
        return FadePageRoute(builder: (_) => const InitialScreen());
      case '/setup':
        return FadePageRoute(builder: (_) => const SetupScreen());
      case '/main':
        return FadePageRoute(
          builder: (_) => MainScreen(
            appName: _appName,
            onRenameApp: setAppName,
            onToggleTheme: setDarkTheme,
            isDarkTheme: _isDarkTheme,
          ),
        );
      case '/settings':
        return FadePageRoute(
          builder: (_) => SettingsScreen(
            appName: _appName,
            onAppNameChanged: setAppName,
            isDarkTheme: _isDarkTheme,
            onThemeChanged: setDarkTheme,
          ),
        );
      default:
        // Fallback
        return FadePageRoute(builder: (_) => const InitialScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _appName.isEmpty ? 'HeritaScan' : _appName,
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

      initialRoute: '/',
      onGenerateRoute: _onGenerateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// The InitialScreen checks if the necessary directories are set.
/// If not, it navigates to the SetupScreen; otherwise, it proceeds to the MainScreen.
class InitialScreen extends StatefulWidget {
  const InitialScreen({Key? key}) : super(key: key);

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  /// Checks if the photos and PDFs directories are already set.
  Future<void> _checkSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final photosDir = prefs.getString('photosDirectory');
    final pdfsDir = prefs.getString('pdfsDirectory');

    if (photosDir == null || pdfsDir == null) {
      // Navigate to SetupScreen if directories are not set.
      Navigator.pushReplacementNamed(context, '/setup');
    } else {
      // Navigate to MainScreen if directories are already set.
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
    // Display a loading indicator while checking the setup.
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF80D0C7), Color(0xFFF9D423)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Lottie.network(
            'https://assets10.lottiefiles.com/packages/lf20_usmfx6bp.json',
            width: 150,
            height: 150,
            fit: BoxFit.contain,
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

  /// Opens a directory picker for the specified type ('photos' or 'pdfs').
  Future<void> _pickDirectory(String type) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      setState(() {
        if (type == 'photos') {
          _photosDirectory = selectedDirectory;
        } else if (type == 'pdfs') {
          _pdfsDirectory = selectedDirectory;
        }
      });
    }
  }

  /// Saves the selected directories to SharedPreferences and navigates to the MainScreen.
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
                      /// Widget to select the Photos Directory.
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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

                      /// Widget to select the PDFs Directory.
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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

                      /// Save Settings Button.
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
class MainScreen extends StatefulWidget {
  final String appName;
  final ValueChanged<String> onRenameApp;
  final ValueChanged<bool> onToggleTheme;
  final bool isDarkTheme;

  const MainScreen({
    super.key,
    required this.appName,
    required this.onRenameApp,
    required this.onToggleTheme,
    required this.isDarkTheme,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final List<File> _photos = [];
  final List<File> _pdfs = [];
  late AnimationController _animationController;

  String? _photosDirectory;
  String? _pdfsDirectory;

  final ImagePicker _picker = ImagePicker(); // for capturing with camera

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadDirectories().then((_) {
      _loadPhotos();
      _loadPdfs();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  /// Capture a photo with the camera and save it
  Future<void> _takePhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile == null) {
        // User canceled the camera
        return;
      }

      final File oldFile = File(pickedFile.path);
      if (await oldFile.exists()) {
        final Directory photosDir = Directory(_photosDirectory!);
        if (!await photosDir.exists()) {
          await photosDir.create(recursive: true);
        }
        final String newPath =
            '${photosDir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final File savedPhoto = await oldFile.copy(newPath);

        setState(() {
          _photos.add(savedPhoto);
        });
        await _savePhotos();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo saved successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing photo: $e')),
      );
    }
  }

  /// Import photos from device gallery into the photos directory
  Future<void> _importPhotos() async {
    try {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage();

      if (pickedFiles == null || pickedFiles.isEmpty) {
        // User canceled the picker
        return;
      }

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

          setState(() {
            _photos.add(savedPhoto);
          });
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

  /// Handles bottom navigation tab selection
  void _onTabTapped(int index) {
    if (_animationController.isAnimating) return;
    setState(() {
      _currentIndex = index;
    });
    _animationController.forward().then((_) => _animationController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    // We build the screens from separate files
    final List<Widget> screens = [
      HomeScreen(
        appName: widget.appName,
        photos: _photos,
        onSave: _savePhotos,
        onPdfGenerated: (pdf) {
          setState(() {
            _pdfs.add(pdf);
          });
          _savePdfs();
        },
        photosDirectory: _photosDirectory,
        pdfsDirectory: _pdfsDirectory,
        onImportPhotos: _importPhotos,
      ),
      const SizedBox(), // Placeholder for the middle tab
      FilesScreen(pdfs: _pdfs),
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.isDarkTheme
                ? [const Color(0xFF181818), const Color(0xFF434343)]
                : [const Color(0xFFECF0F1), const Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: screens[_currentIndex],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              /// Home tab
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _currentIndex == 0
                        ? 1 + _animationController.value * 0.2
                        : 1,
                    child: IconButton(
                      icon: Icon(
                        Icons.home_rounded,
                        size: 28,
                        color: _currentIndex == 0
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).iconTheme.color,
                      ),
                      onPressed: () => _onTabTapped(0),
                      tooltip: 'Home',
                    ),
                  );
                },
              ),
              const SizedBox(width: 48),

              /// Files tab
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _currentIndex == 2
                        ? 1 + _animationController.value * 0.2
                        : 1,
                    child: IconButton(
                      icon: Icon(
                        Icons.folder_shared_rounded,
                        size: 28,
                        color: _currentIndex == 2
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).iconTheme.color,
                      ),
                      onPressed: () => _onTabTapped(2),
                      tooltip: 'Files',
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePhoto,
        tooltip: 'Take Photo',
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.camera_alt_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}