import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart'; // Added image_picker
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:image/image.dart' as img;
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global app version string
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
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
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

  /// Helper to read preferences anywhere
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
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
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
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
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
      // Use a gradient background for a modern look
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

    // Navigate to MainScreen after saving directories.
    Navigator.pushReplacementNamed(context, '/main');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Subtle gradient for Setup
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
/// It also receives the dynamic app name and handles theme toggling callback.
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

  final ImagePicker _picker = ImagePicker(); // Initialize ImagePicker

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

  /// Loads the directories from SharedPreferences.
  Future<void> _loadDirectories() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _photosDirectory = prefs.getString('photosDirectory');
      _pdfsDirectory = prefs.getString('pdfsDirectory');
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  /// Uses image_picker to capture a photo with the camera,
  /// then saves it to the photos directory and displays it in the gallery.
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

        // Update UI to show the newly captured photo in the home “gallery”
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

  /// Uses image_picker to import photos from the device's gallery,
  /// then saves them to the photos directory and displays them in the gallery.
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

          // Update UI to show the newly imported photo in the home “gallery”
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

  /// Handles tab selection with animation feedback.
  void _onTabTapped(int index) {
    if (_animationController.isAnimating) return;
    setState(() {
      _currentIndex = index;
    });
    _animationController
        .forward()
        .then((_) => _animationController.reverse());
  }

  @override
  Widget build(BuildContext context) {
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
        onImportPhotos: _importPhotos, // Pass the import function
      ),
      // Placeholder (middle tab)
      const SizedBox(),
      FilesScreen(pdfs: _pdfs),
    ];

    return Scaffold(
      // Subtle gradient background
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
        onPressed: _takePhoto, // Changed to takePhoto
        tooltip: 'Take Photo',
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.camera_alt_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

/// The HomeScreen displays a grid of captured photos and provides functionalities
/// like editing, sharing, deleting, generating PDFs, and a **Select All** button.
/// Also includes an import button to import photos from the device's gallery.
class HomeScreen extends StatefulWidget {
  final String appName;
  final List<File> photos;
  final Future<void> Function() onSave;
  final void Function(File) onPdfGenerated;
  final String? photosDirectory;
  final String? pdfsDirectory;
  final Future<void> Function() onImportPhotos; // Added import function

  const HomeScreen({
    super.key,
    required this.appName,
    required this.photos,
    required this.onSave,
    required this.onPdfGenerated,
    required this.photosDirectory,
    required this.pdfsDirectory,
    required this.onImportPhotos, // Receive import function
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Set<int> _selectedIndices = {};
  bool _selectionMode = false;

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedIndices.add(index);
        _selectionMode = true;
      }
    });
  }

  /// Generates a PDF from selected photos.
  Future<void> _generatePdf() async {
    if (_selectedIndices.isEmpty) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Container(
        color: Colors.black54,
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

    try {
      await Future.wait([
        _generatePdfInternal(),
        Future.delayed(const Duration(seconds: 2)),
      ]);

      setState(() {
        _selectedIndices.clear();
        _selectionMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF Generated Successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    } finally {
      Navigator.pop(context);
    }
  }

  Future<void> _generatePdfInternal() async {
    final pdf = pw.Document();
    final List<int> indices = _selectedIndices.toList()..sort();

    for (var index in indices) {
      final Uint8List imageBytes =
          await _resizeImage(widget.photos[index].path, quality: 100);
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(
            child: pw.Image(image),
          ),
        ),
      );
    }

    final Directory pdfDir = Directory(widget.pdfsDirectory!);
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }

    final file = File(
      '${pdfDir.path}/photos_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    widget.onPdfGenerated(file);
  }

  Future<Uint8List> _resizeImage(String path,
      {int? maxWidth, int? maxHeight, int? quality}) async {
    final bytes = await File(path).readAsBytes();
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Failed to decode image.');
    }

    final List<int> compressed =
        img.encodeJpg(decoded, quality: quality ?? 100);
    return Uint8List.fromList(compressed);
  }

  void _deleteSelectedPhotos() {
    if (_selectedIndices.isEmpty) return;

    List<File> photosToDelete = [];
    for (var idx in _selectedIndices) {
      photosToDelete.add(widget.photos[idx]);
    }

    setState(() {
      widget.photos.removeWhere((photo) => photosToDelete.contains(photo));
      _selectedIndices.clear();
      _selectionMode = false;
    });

    widget.onSave();

    for (var photo in photosToDelete) {
      if (photo.existsSync()) {
        photo.deleteSync();
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selected photos deleted!')),
    );
  }

  void _shareSelectedPhotos() async {
    if (_selectedIndices.isEmpty) return;

    List<XFile> filesToShare = [];
    for (var idx in _selectedIndices) {
      filesToShare.add(XFile(widget.photos[idx].path));
    }

    try {
      await Share.shareXFiles(filesToShare, text: 'Check out these photos!');
      setState(() {
        _selectedIndices.clear();
        _selectionMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing photos: $e')),
      );
    }
  }

  void _openFullScreenImage(int index) async {
    try {
      File? updatedImage = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenImage(
            imageFile: widget.photos[index],
          ),
        ),
      );

      if (updatedImage != null) {
        setState(() {
          widget.photos[index] = updatedImage;
        });
        widget.onSave();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening image: $e')),
      );
    }
  }

  void _cancelSelection() {
    setState(() {
      _selectedIndices.clear();
      _selectionMode = false;
    });
  }

  void _selectAllOrNone() {
    final allSelected = _selectedIndices.length == widget.photos.length;
    setState(() {
      if (allSelected) {
        _selectedIndices.clear();
        _selectionMode = false;
      } else {
        _selectedIndices =
            Set.from(List.generate(widget.photos.length, (i) => i));
        _selectionMode = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selectedIndices.length == widget.photos.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: 70,
        elevation: 0,
        centerTitle: false,
        title: _selectionMode
            ? Text(
                'Selected (${_selectedIndices.length})',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.appName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Row(
                    children: [
                      /// Import Photos Button
                      IconButton(
                        icon: Icon(Icons.photo_sharp),
                        onPressed: widget.onImportPhotos,
                        tooltip: 'Import Photos',
                      ),

                      /// Settings Button
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          Navigator.pushNamed(context, '/settings');
                        },
                        tooltip: 'Settings',
                      ),
                    ],
                  ),
                ],
              ),
        backgroundColor: Colors.transparent,
        actions: _selectionMode
            ? [
                IconButton(
                  icon: Icon(
                      allSelected ? Icons.clear_all : Icons.select_all),
                  onPressed: _selectAllOrNone,
                  tooltip:
                      allSelected ? 'Deselect All' : 'Select All',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteSelectedPhotos,
                  tooltip: 'Delete',
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _shareSelectedPhotos,
                  tooltip: 'Share',
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: _generatePdf,
                  tooltip: 'Generate PDF',
                ),
              ]
            : null,
      ),
      body: widget.photos.isEmpty
          ? const Center(
              child: Text(
                'Tap the camera button to take a photo or import from gallery.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: widget.photos.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedIndices.contains(index);
                return GestureDetector(
                  onTap: () {
                    if (_selectionMode) {
                      _toggleSelection(index);
                    } else {
                      _openFullScreenImage(index);
                    }
                  },
                  onLongPress: () => _toggleSelection(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.file(
                              widget.photos[index],
                              fit: BoxFit.cover,
                              key: ValueKey(
                                widget.photos[index].path +
                                    (isSelected ? 'selected' : ''),
                              ),
                              frameBuilder:
                                  (context, child, frame,
                                      wasSynchronouslyLoaded) {
                                if (wasSynchronouslyLoaded)
                                  return child;
                                return AnimatedOpacity(
                                  opacity: frame == null ? 0 : 1,
                                  duration:
                                      const Duration(seconds: 1),
                                  child: child,
                                );
                              },
                            ),
                          ),
                          if (isSelected)
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.5),
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// The FilesScreen displays a list of generated PDFs and provides functionalities
/// to view (with a loading screen), share, and delete them.
class FilesScreen extends StatefulWidget {
  final List<File> pdfs;

  const FilesScreen({super.key, required this.pdfs});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  Set<int> _selectedIndices = {};
  bool _selectionMode = false;

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Container(
        color: Colors.black54,
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

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedIndices.add(index);
        _selectionMode = true;
      }
    });
  }

  Future<void> _openPdf(File file) async {
    _showLoadingDialog();

    try {
      if (!await file.exists()) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File does not exist.')),
        );
        return;
      }

      final result = await OpenFilex.open(file.path);
      Navigator.pop(context);

      if (result.type != ResultType.done) {
        // Fallback to in-app PDF viewer
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(path: file.path),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening PDF: $e')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(path: file.path),
        ),
      );
    }
  }

  void _onPdfTap(int index) {
    if (_selectionMode) {
      _toggleSelection(index);
    } else {
      _openPdf(widget.pdfs[index]);
    }
  }

  void _onPdfLongPress(int index) {
    _toggleSelection(index);
  }

  Future<void> _deleteSelectedPdfs() async {
    if (_selectedIndices.isEmpty) return;

    List<File> filesToDelete = [];
    for (var idx in _selectedIndices) {
      filesToDelete.add(widget.pdfs[idx]);
    }

    try {
      for (var file in filesToDelete) {
        if (await file.exists()) {
          await file.delete();
        }
      }

      setState(() {
        widget.pdfs.removeWhere((pdf) => filesToDelete.contains(pdf));
        _selectedIndices.clear();
        _selectionMode = false;
      });

      final prefs = await SharedPreferences.getInstance();
      final pdfPaths = widget.pdfs.map((file) => file.path).toList();
      await prefs.setStringList('pdfs', pdfPaths);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected PDFs deleted!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting PDFs: $e')),
      );
    }
  }

  Future<void> _shareSelectedPdfs() async {
    if (_selectedIndices.isEmpty) return;

    List<XFile> filesToShare = [];
    for (var idx in _selectedIndices) {
      filesToShare.add(XFile(widget.pdfs[idx].path));
    }

    try {
      await Share.shareXFiles(filesToShare, text: 'Check out these PDFs!');
      setState(() {
        _selectedIndices.clear();
        _selectionMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing PDFs: $e')),
      );
    }
  }

  Future<void> _confirmDeleteSelectedPdfs() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete PDFs'),
        content:
            const Text('Are you sure you want to delete the selected PDFs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _deleteSelectedPdfs();
    }
  }

  void _cancelSelection() {
    setState(() {
      _selectedIndices.clear();
      _selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _selectionMode
          ? AppBar(
              title: Text('${_selectedIndices.length} Selected'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _shareSelectedPdfs,
                  tooltip: 'Share',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _confirmDeleteSelectedPdfs,
                  tooltip: 'Delete',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _cancelSelection,
                  tooltip: 'Cancel',
                ),
              ],
            )
          : AppBar(
              toolbarHeight: 70,
              elevation: 0,
              centerTitle: false,
              backgroundColor: Colors.transparent,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Files',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
                ? [const Color(0xFF262626), const Color(0xFF3A3A3A)]
                : [const Color(0xFFFDFDFD), const Color(0xFFEFEFEF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: widget.pdfs.isEmpty
            ? const Center(
                child: Text(
                  'No PDFs available.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                itemCount: widget.pdfs.length,
                itemBuilder: (context, index) {
                  final file = widget.pdfs[index];
                  final isSelected = _selectedIndices.contains(index);
                  return GestureDetector(
                    onTap: () => _onPdfTap(index),
                    onLongPress: () => _onPdfLongPress(index),
                    child: Container(
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3)
                          : Colors.transparent,
                      child: ListTile(
                        leading:
                            const Icon(Icons.picture_as_pdf, color: Colors.red),
                        title: Text(
                          file.path.split('/').last,
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.color,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.white)
                            : null,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// The PdfViewerScreen displays the PDF using the flutter_pdfview package.
class PdfViewerScreen extends StatelessWidget {
  final String path;

  const PdfViewerScreen({Key? key, required this.path}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Subtle gradient
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFBBD2C5), Color(0xFF536976)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('View PDF'),
                backgroundColor: Colors.transparent,
              ),
              Expanded(
                child: PDFView(
                  filePath: path,
                  enableSwipe: true,
                  nightMode: false,
                  swipeHorizontal: true,
                  autoSpacing: false,
                  pageFling: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The FullScreenImage widget allows users to view and edit an image in full screen.
class FullScreenImage extends StatefulWidget {
  final File imageFile;

  const FullScreenImage({Key? key, required this.imageFile}) : super(key: key);

  @override
  _FullScreenImageState createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  late File _editedImage;
  bool _isEditing = false;
  int _imageVersion = 0; // Version counter to force rebuild

  @override
  void initState() {
    super.initState();
    _editedImage = widget.imageFile;
  }

  /// Launches the image editor to allow users to edit the image.
  Future<void> _launchEditor() async {
    setState(() {
      _isEditing = true;
    });

    try {
      Uint8List imageData = await _editedImage.readAsBytes();

      final editedImageBytes = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEditor(image: imageData),
        ),
      );

      if (editedImageBytes != null && editedImageBytes is Uint8List) {
        await _editedImage.writeAsBytes(editedImageBytes);

        setState(() {
          _imageVersion++;
        });

        // Clear image cache to force reload
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image edited successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error editing image: $e')),
      );
    } finally {
      setState(() {
        _isEditing = false;
      });
    }
  }

  void _saveImage() {
    Navigator.pop(context, _editedImage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Subtle gradient
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFDE6262), Color(0xFFFFB88C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: _isEditing
                    ? const Text(
                        'Editing...',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      )
                    : const Text(
                        'Full Image',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                backgroundColor: Colors.transparent,
                actions: _isEditing
                    ? []
                    : [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 24),
                          onPressed: _launchEditor,
                          tooltip: 'Edit Image',
                        ),
                        IconButton(
                          icon: const Icon(Icons.check, size: 24),
                          onPressed: _saveImage,
                          tooltip: 'Save',
                        ),
                      ],
              ),
              Expanded(
                child: Center(
                  child: Image.file(
                    _editedImage,
                    key: ValueKey(_imageVersion),
                    fit: BoxFit.contain,
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

/// The SettingsScreen allows changing:
/// - App Name
/// - Theme (Light/Dark)
/// - Directories for Photos/PDFs
/// - Displays app version
class SettingsScreen extends StatefulWidget {
  final String appName;
  final ValueChanged<String> onAppNameChanged;
  final bool isDarkTheme;
  final ValueChanged<bool> onThemeChanged;

  const SettingsScreen({
    Key? key,
    required this.appName,
    required this.onAppNameChanged,
    required this.isDarkTheme,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _appNameController;
  String? _photosDirectory;
  String? _pdfsDirectory;

  @override
  void initState() {
    super.initState();
    _appNameController = TextEditingController(text: widget.appName);
    _loadDirectories();
  }

  Future<void> _loadDirectories() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _photosDirectory = prefs.getString('photosDirectory');
      _pdfsDirectory = prefs.getString('pdfsDirectory');
    });
  }

  Future<void> _pickDirectory(String type) async {
    String? selectedDirectory =
        await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (type == 'photos') {
      setState(() {
        _photosDirectory = selectedDirectory;
      });
      await prefs.setString('photosDirectory', selectedDirectory);
    } else if (type == 'pdfs') {
      setState(() {
        _pdfsDirectory = selectedDirectory;
      });
      await prefs.setString('pdfsDirectory', selectedDirectory);
    }
  }

  void _updateAppName() {
    widget.onAppNameChanged(_appNameController.text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F2027), const Color(0xFF203A43)]
                : [const Color(0xFFa8c0ff), const Color(0xFFfbc2eb)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Settings'),
                backgroundColor: Colors.transparent,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    /// App Name
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: const Text('App Name'),
                        subtitle: TextField(
                          controller: _appNameController,
                          decoration: const InputDecoration(
                            hintText: 'Enter a custom name',
                          ),
                          onSubmitted: (_) => _updateAppName(),
                          onEditingComplete: _updateAppName,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    /// Dark Theme Toggle
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        title: const Text('Dark Theme'),
                        value: isDark,
                        onChanged: (bool value) {
                          widget.onThemeChanged(value);
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    /// Photos Directory
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: const Text('Photos Directory'),
                        subtitle: Text(_photosDirectory ?? 'Not set'),
                        trailing: ElevatedButton(
                          onPressed: () => _pickDirectory('photos'),
                          child: const Text('Change'),
                        ),
                      ),
                    ),

                    /// PDFs Directory
                    const SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: const Text('PDFs Directory'),
                        subtitle: Text(_pdfsDirectory ?? 'Not set'),
                        trailing: ElevatedButton(
                          onPressed: () => _pickDirectory('pdfs'),
                          child: const Text('Change'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    /// App Version
                    Center(
                      child: Text(
                        'Version: $kAppVersion',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}