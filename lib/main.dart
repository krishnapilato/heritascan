import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:image/image.dart' as img;
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart'; // Example of an additional library

void main() {
  runApp(const MyApp());
}

/// The root widget of the application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HeritaScan',
      themeMode: ThemeMode.system, // Follow system theme
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const InitialScreen(),
        '/setup': (context) => const SetupScreen(),
        '/main': (context) => const MainScreen(),
      },
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
        color: Colors.white,
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
      appBar: AppBar(
        title: const Text('Setup HeritaScan'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            /// Widget to select the Photos Directory.
            ListTile(
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
            const SizedBox(height: 20),

            /// Widget to select the PDFs Directory.
            ListTile(
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
            const Spacer(),

            /// Save Settings Button.
            ElevatedButton(
              onPressed: _saveDirectories,
              child: const Text('Save Settings'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The MainScreen hosts the primary functionalities of the app, including Home and Files tabs.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

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

  /// Handles the photo capture process.
  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        // Removed maxWidth and maxHeight to keep original size
        imageQuality: 100, // Set to maximum quality
      );

      if (photo != null) {
        final File newPhoto = File(photo.path);
        await precacheImage(FileImage(newPhoto), context);

        // Move the photo to the selected photos directory.
        final Directory photosDir = Directory(_photosDirectory!);
        if (!await photosDir.exists()) {
          await photosDir.create(recursive: true);
        }
        final String newPath =
            '${photosDir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final File savedPhoto = await newPhoto.copy(newPath);

        setState(() {
          _photos.add(savedPhoto);
        });
        _savePhotos();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Expanded(child: Text('Photo captured successfully!'))
              ],
            ),
          ),
        );
      }
    } catch (e) {
      // Handle any errors during photo capture.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking photo: $e')),
      );
    }
  }

  /// Handles tab selection with animation feedback.
  void _onTabTapped(int index) {
    if (_animationController.isAnimating) return;
    setState(() {
      _currentIndex = index;
    });
    _animationController.forward().then((_) => _animationController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      /// HomeScreen displays the grid of photos and provides options to edit, share, delete, generate PDFs, and **select all**.
      HomeScreen(
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
      ),

      /// Placeholder for potential future tabs.
      const SizedBox(),

      /// FilesScreen displays the list of generated PDFs.
      FilesScreen(pdfs: _pdfs),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              /// Home Tab Button with Animation.
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

              /// Files Tab Button with Animation.
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
        tooltip: 'Take Picture',
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.camera_enhance_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

/// The HomeScreen displays a grid of captured photos and provides functionalities
/// like editing, sharing, deleting, generating PDFs, and a **Select All** button.
class HomeScreen extends StatefulWidget {
  final List<File> photos;
  final Future<void> Function() onSave;
  final void Function(File) onPdfGenerated;
  final String? photosDirectory;
  final String? pdfsDirectory;

  const HomeScreen({
    super.key,
    required this.photos,
    required this.onSave,
    required this.onPdfGenerated,
    required this.photosDirectory,
    required this.pdfsDirectory,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Set<int> _selectedIndices = {};
  bool _selectionMode = false;

  /// Toggles the selection of a photo at the given index.
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

  /// Generates a PDF from selected photos with a spinner while processing.
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

    // Start PDF generation and wait for at least 5 seconds
    try {
      await Future.wait([
        _generatePdfInternal(),
        Future.delayed(const Duration(seconds: 5)),
      ]);

      setState(() {
        _selectedIndices.clear();
        _selectionMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF Generated Successfully!')),
      );
    } catch (e) {
      // Handle errors during PDF generation.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    } finally {
      // Dismiss loading dialog
      Navigator.pop(context);
    }
  }

  /// Internal method to handle PDF generation.
  Future<void> _generatePdfInternal() async {
    final pdf = pw.Document();

    // Sort the selected indices to ensure proper order.
    final List<int> orderedSelectedIndices = _selectedIndices.toList();

    for (var index in orderedSelectedIndices) {
      // Resize image (if needed) before adding to PDF.
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

    // Save the PDF file.
    final Directory pdfDir = Directory(widget.pdfsDirectory!);
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }

    final file = File(
        '${pdfDir.path}/photos_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    widget.onPdfGenerated(file);
  }

  /// Resizes and compresses the image at the given path.
  /// Processes the image without degrading quality or resizing unnecessarily.
  Future<Uint8List> _resizeImage(String path,
      {int? maxWidth, int? maxHeight, int? quality}) async {
    // Read the original image file as bytes
    final bytes = await File(path).readAsBytes();
    final img.Image? image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Failed to decode image.');
    }

    // Check if resizing is needed
    if ((maxWidth != null && image.width > maxWidth) ||
        (maxHeight != null && image.height > maxHeight)) {
      img.Image resized = img.copyResize(
        image,
        width: maxWidth,
        height: maxHeight,
        interpolation: img.Interpolation.linear,
      );

      // Compress the resized image to specified quality
      final List<int> compressed =
          img.encodeJpg(resized, quality: quality ?? 100);
      return Uint8List.fromList(compressed);
    }

    // If no resizing is required, just return the original image bytes
    final List<int> compressed =
        img.encodeJpg(image, quality: quality ?? 100);
    return Uint8List.fromList(compressed);
  }

  /// Deletes the selected photos from storage and the app's state.
  void _deleteSelectedPhotos() {
    if (_selectedIndices.isEmpty) return;

    List<File> photosToDelete = [];
    _selectedIndices.forEach((index) {
      photosToDelete.add(widget.photos[index]);
    });

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

  /// Shares the selected photos using the share_plus package.
  void _shareSelectedPhotos() async {
    if (_selectedIndices.isEmpty) return;

    List<XFile> filesToShare = [];
    for (var index in _selectedIndices) {
      filesToShare.add(XFile(widget.photos[index].path));
    }

    try {
      await Share.shareXFiles(filesToShare, text: 'Check out these photos!');
      setState(() {
        _selectedIndices.clear();
        _selectionMode = false;
      });
    } catch (e) {
      // Handle sharing errors.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing photos: $e')),
      );
    }
  }

  /// Opens the FullScreenImage widget for editing the selected photo.
  void _openFullScreenImage(int index) async {
    try {
      File? updatedImage = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FullScreenImage(imageFile: widget.photos[index]),
        ),
      );

      if (updatedImage != null) {
        setState(() {
          widget.photos[index] = updatedImage;
        });
        widget.onSave();
      }
    } catch (e) {
      // Handle navigation or image update errors.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening image: $e')),
      );
    }
  }

  /// Cancels the current selection mode.
  Future<void> _cancelSelection() async {
    setState(() {
      _selectedIndices.clear();
      _selectionMode = false;
    });
  }

  /// Toggles between "Select All" and "Deselect All" when in selection mode.
  void _selectAllOrNone() {
    final allSelected = _selectedIndices.length == widget.photos.length;
    setState(() {
      if (allSelected) {
        // Deselect all
        _selectedIndices.clear();
        _selectionMode = false;
      } else {
        // Select all
        _selectedIndices =
            Set.from(Iterable<int>.generate(widget.photos.length));
        _selectionMode = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selectedIndices.length == widget.photos.length;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        title: _selectionMode
            ? Text(
                'Selected (${_selectedIndices.length})',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'HeritaScan',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
        actions: _selectionMode
            ? [
                /// Select All / Deselect All Button.
                IconButton(
                  icon: Icon(
                    allSelected
                        ? Icons.clear_all
                        : Icons.select_all_outlined,
                  ),
                  onPressed: _selectAllOrNone,
                  tooltip: allSelected ? 'Deselect All' : 'Select All',
                ),

                /// Delete Button.
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteSelectedPhotos,
                  tooltip: 'Delete',
                ),

                /// Share Button.
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _shareSelectedPhotos,
                  tooltip: 'Share',
                ),

                /// Generate PDF Button.
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: _generatePdf,
                  tooltip: 'Generate PDF',
                )
              ]
            : null,
      ),
      body: widget.photos.isEmpty
          ? const Center(
              child: Text(
                'Tap the camera button to capture some.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Number of columns.
                crossAxisSpacing: 12, // Horizontal spacing.
                mainAxisSpacing: 12, // Vertical spacing.
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        /// Displays the photo.
                        Positioned.fill(
                          child: Image.file(
                            widget.photos[index],
                            fit: BoxFit.cover,
                            key: ValueKey(widget.photos[index].path +
                                (isSelected ? 'selected' : '')),
                            frameBuilder: (context, child, frame,
                                wasSynchronouslyLoaded) {
                              if (wasSynchronouslyLoaded) return child;
                              return AnimatedOpacity(
                                opacity: frame == null ? 0 : 1,
                                duration: const Duration(seconds: 1),
                                child: child,
                              );
                            },
                          ),
                        ),

                        /// Overlay to indicate selection.
                        if (isSelected)
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
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

  /// Shows a modal loading dialog with a Lottie animation.
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissal by tapping outside
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

  /// Toggles the selection of a PDF at the given index.
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

  /// Opens the PDF using OpenFilex or falls back to an in-app PDF viewer.
  Future<void> _openPdf(File file) async {
    // Show a full-screen loading spinner:
    _showLoadingDialog();

    try {
      // Check if the file exists.
      if (!await file.exists()) {
        Navigator.pop(context); // Close the loading spinner
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File does not exist.')),
        );
        return;
      }

      // Attempt to open the PDF using OpenFilex.
      final result = await OpenFilex.open(file.path);

      // Close the loading spinner before checking the result:
      Navigator.pop(context);

      if (result.type != ResultType.done) {
        // Fallback to in-app PDF viewer if external open failed or not available
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(path: file.path),
          ),
        );
      }
    } catch (e) {
      // Close the loading spinner on error
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening PDF: $e')),
      );
      // Fallback to in-app PDF viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(path: file.path),
        ),
      );
    }
  }

  /// Handles tap on a PDF item.
  void _onPdfTap(int index) {
    _openPdf(widget.pdfs[index]);
  }

  /// Handles long press on a PDF item.
  void _onPdfLongPress(int index) {
    _toggleSelection(index);
  }

  /// Deletes the selected PDFs after user confirmation.
  Future<void> _deleteSelectedPdfs() async {
    if (_selectedIndices.isEmpty) return;

    List<File> filesToDelete = [];
    _selectedIndices.forEach((index) {
      filesToDelete.add(widget.pdfs[index]);
    });

    try {
      for (var file in filesToDelete) {
        if (await file.exists()) {
          await file.delete();
        }
      }

      setState(() {
        widget.pdfs.removeWhere((file) => filesToDelete.contains(file));
        _selectedIndices.clear();
        _selectionMode = false;
      });

      // Update SharedPreferences with the new list of PDFs.
      final prefs = await SharedPreferences.getInstance();
      final pdfPaths = widget.pdfs.map((file) => file.path).toList();
      await prefs.setStringList('pdfs', pdfPaths);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected PDFs deleted!')),
      );
    } catch (e) {
      // Handle deletion errors.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting PDFs: $e')),
      );
    }
  }

  /// Shares the selected PDFs using the share_plus package.
  Future<void> _shareSelectedPdfs() async {
    if (_selectedIndices.isEmpty) return;

    List<XFile> filesToShare = [];
    for (var index in _selectedIndices) {
      filesToShare.add(XFile(widget.pdfs[index].path));
    }

    try {
      await Share.shareXFiles(filesToShare, text: 'Check out these PDFs!');
      setState(() {
        _selectedIndices.clear();
        _selectionMode = false;
      });
    } catch (e) {
      // Handle sharing errors.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing PDFs: $e')),
      );
    }
  }

  /// Shows a confirmation dialog before deleting selected PDFs.
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

  /// Cancels the current selection mode.
  Future<void> _cancelSelection() async {
    setState(() {
      _selectedIndices.clear();
      _selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              title: Text('${_selectedIndices.length} Selected'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              actions: [
                /// Share Button.
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _shareSelectedPdfs,
                  tooltip: 'Share',
                ),

                /// Delete Button.
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _confirmDeleteSelectedPdfs,
                  tooltip: 'Delete',
                ),

                /// Cancel Selection Button.
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
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              centerTitle: false,
              backgroundColor: Colors.transparent,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'HeritaScan Files',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
      body: widget.pdfs.isEmpty
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
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.white)
                          : null,
                    ),
                  ),
                );
              },
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
      appBar: AppBar(
        title: const Text('View PDF'),
      ),
      body: PDFView(
        filePath: path,
        enableSwipe: true,
        nightMode: false, // Always use light theme
        swipeHorizontal: true,
        autoSpacing: false,
        pageFling: true,
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
  int _imageVersion = 0; // Version counter to assign unique Key

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
      // Read the image file as bytes.
      Uint8List imageData = await _editedImage.readAsBytes();

      // Launch the ImageEditorPlus.
      final editedImageBytes = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEditor(image: imageData),
        ),
      );

      if (editedImageBytes != null && editedImageBytes is Uint8List) {
        // Save the edited image back to the file.
        await _editedImage.writeAsBytes(editedImageBytes);

        // Increment the version to assign a new Key, forcing the Image widget to rebuild.
        setState(() {
          _imageVersion++;
        });

        // Clear the image cache to force Flutter to reload the updated image.
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();

        // Notify the user of successful editing.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image edited successfully!')),
        );
      }
    } catch (e) {
      // Handle any errors that occur during the editing process.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error editing image: $e')),
      );
    } finally {
      // Reset the editing state.
      setState(() {
        _isEditing = false;
      });
    }
  }

  /// Saves the edited image and returns to the previous screen.
  void _saveImage() {
    Navigator.pop(context, _editedImage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isEditing
            ? const Text(
                'Editing...',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              )
            : Text(
                'HeritaScan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
        backgroundColor: Colors.black,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
        actions: _isEditing
            ? []
            : [
                /// Edit Image Button.
                IconButton(
                  icon: const Icon(Icons.edit, size: 24),
                  onPressed: _launchEditor,
                  tooltip: 'Edit Image',
                ),

                /// Save Image Button.
                IconButton(
                  icon: const Icon(Icons.check, size: 24),
                  onPressed: _saveImage,
                  tooltip: 'Save',
                ),
              ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white,
              child: Center(
                child: Image.file(
                  _editedImage,
                  key: ValueKey(
                      _imageVersion), // Assign unique Key to force rebuild.
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}