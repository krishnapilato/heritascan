import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart'; // For taking photos

import 'edit_photo.dart'; // For your FullScreenImage screen

class HomeScreen extends StatefulWidget {
  final List<File> photos;
  final Future<void> Function() onSave;
  final void Function(File) onPdfGenerated;
  final String? photosDirectory;
  final String? pdfsDirectory;
  final Future<void> Function() onImportPhotos;

  const HomeScreen({
    Key? key,
    required this.photos,
    required this.onSave,
    required this.onPdfGenerated,
    required this.photosDirectory,
    required this.pdfsDirectory,
    required this.onImportPhotos,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Selection variables.
  Set<String> _selectedPaths = {};
  bool _selectionMode = false;

  // Grid layout: 2 or 3 columns.
  int _gridColumns = 2;

  // Sorting option: 'date_desc', 'date_asc', 'name_asc', 'name_desc'
  String _sortOption = 'date_desc';

  // Search mode.
  bool _isSearching = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // Favorites tracking.
  Set<String> _favoritePaths = {};
  bool _showFavorites = false;

  // Controls expansion of FAB (to show camera & import options)
  bool _isFabExpanded = false;

  // Returns a sorted (and filtered) copy of the photos list.
  List<File> get sortedPhotos {
    List<File> list = List.from(widget.photos);

    // Apply favorites filtering if enabled.
    if (_showFavorites) {
      list = list.where((file) => _favoritePaths.contains(file.path)).toList();
    }

    // Apply search filtering if active.
    if (_isSearching && _searchQuery.isNotEmpty) {
      list = list.where((file) {
        final name = file.path.split(Platform.pathSeparator).last.toLowerCase();
        return name.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Sorting.
    switch (_sortOption) {
      case 'date_desc':
        list.sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        break;
      case 'date_asc':
        list.sort(
            (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
        break;
      case 'name_asc':
        list.sort((a, b) => a.path
            .split(Platform.pathSeparator)
            .last
            .toLowerCase()
            .compareTo(
                b.path.split(Platform.pathSeparator).last.toLowerCase()));
        break;
      case 'name_desc':
        list.sort((a, b) => b.path
            .split(Platform.pathSeparator)
            .last
            .toLowerCase()
            .compareTo(
                a.path.split(Platform.pathSeparator).last.toLowerCase()));
        break;
      default:
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allSelected = _selectedPaths.length == sortedPhotos.length;
    final isEmpty = widget.photos.isEmpty;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false, // Title is left-aligned.
        automaticallyImplyLeading: false,
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel Selection',
                onPressed: _cancelSelection,
              )
            : null,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isSearching
              ? TextField(
                  key: const ValueKey('searchField'),
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search photos...',
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.cancel),
                      onPressed: () {
                        setState(() {
                          _isSearching = false;
                          _searchQuery = "";
                          _searchController.clear();
                        });
                      },
                    ),
                  ),
                  style: const TextStyle(fontSize: 20),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                )
              : Text(
                  _selectionMode
                      ? 'Selected (${_selectedPaths.length})'
                      : 'Images',
                  key: const ValueKey('title'),
                  style: TextStyle(
                    fontSize: _selectionMode ? 18 : 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        actions: _selectionMode
            ? [
                IconButton(
                  icon: Icon(allSelected ? Icons.clear_all : Icons.select_all),
                  tooltip: allSelected ? 'Deselect All' : 'Select All',
                  onPressed: _selectAllOrNone,
                ),
                // NEW: Bulk favorites button.
                IconButton(
                  icon: Icon(
                    _allSelectedAreFavorite() ? Icons.star : Icons.star_border,
                  ),
                  tooltip: _allSelectedAreFavorite()
                      ? 'Remove from Favorites'
                      : 'Add to Favorites',
                  onPressed: _toggleFavoriteForSelectedPhotos,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete',
                  onPressed: _deleteSelectedPhotos,
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Share',
                  onPressed: _shareSelectedPhotos,
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'Generate PDF',
                  onPressed: _generatePdf,
                ),
              ]
            : _isSearching
                ? [] // Hide actions when searching.
                : [
                    IconButton(
                      icon: Icon(
                        _isSearching ? Icons.cancel : Icons.search,
                      ),
                      tooltip: _isSearching ? 'Cancel Search' : 'Search',
                      onPressed: () {
                        setState(() {
                          if (_isSearching) {
                            _searchQuery = "";
                            _searchController.clear();
                          }
                          _isSearching = !_isSearching;
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        _gridColumns == 2
                            ? Icons.grid_view_rounded
                            : Icons.view_comfy,
                      ),
                      tooltip: 'Toggle Layout',
                      onPressed: _toggleGalleryLayout,
                    ),
                    // Sorting popup.
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort),
                      tooltip: 'Sort Photos',
                      onSelected: (value) {
                        setState(() {
                          _sortOption = value;
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'date_desc',
                          child: Text('Date: Newest First'),
                        ),
                        const PopupMenuItem(
                          value: 'date_asc',
                          child: Text('Date: Oldest First'),
                        ),
                        const PopupMenuItem(
                          value: 'name_asc',
                          child: Text('Name: A-Z'),
                        ),
                        const PopupMenuItem(
                          value: 'name_desc',
                          child: Text('Name: Z-A'),
                        ),
                      ],
                    ),
                    // Favorites filter toggle.
                    IconButton(
                      icon: Icon(_showFavorites
                          ? Icons.favorite
                          : Icons.favorite_border),
                      tooltip:
                          _showFavorites ? 'Show All Photos' : 'Show Favorites',
                      onPressed: () {
                        setState(() {
                          _showFavorites = !_showFavorites;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_rounded),
                      tooltip: 'Settings',
                      onPressed: () =>
                          Navigator.pushNamed(context, '/settings'),
                    ),
                  ],
      ),
      body: CustomScrollView(
        slivers: [
          if (isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Lottie.network(
                      'https://assets10.lottiefiles.com/packages/lf20_jcikwtux.json',
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap the camera button to take a photo\nor import from gallery.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            // Add a top margin for the grid view.
            SliverPadding(
              padding: const EdgeInsets.only(
                  top: 55, left: 12, right: 12, bottom: 12),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridColumns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final photo = sortedPhotos[index];
                    final isSelected = _selectedPaths.contains(photo.path);
                    return GestureDetector(
                      onTap: () {
                        if (_selectionMode) {
                          _toggleSelection(photo);
                        } else {
                          _openFullScreenImage(photo);
                        }
                      },
                      onLongPress: () => _toggleSelection(photo),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected
                              ? Border.all(
                                  color: theme.colorScheme.primary, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.4),
                                  )
                                ]
                              : [
                                  if (theme.brightness == Brightness.light)
                                    const BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                photo,
                                fit: BoxFit.cover,
                                key: ValueKey(photo.path +
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
                              if (isSelected)
                                Container(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.4),
                                  child: const Center(
                                    child: Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              // Show individual favorite icon only when not in selection mode.
                              if (!_selectionMode)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (_favoritePaths
                                            .contains(photo.path)) {
                                          _favoritePaths.remove(photo.path);
                                        } else {
                                          _favoritePaths.add(photo.path);
                                        }
                                      });
                                    },
                                    child: Icon(
                                      _favoritePaths.contains(photo.path)
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.yellowAccent,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: sortedPhotos.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Toggle between 2 and 3 columns.
  void _toggleGalleryLayout() {
    setState(() {
      _gridColumns = (_gridColumns == 2) ? 3 : 2;
    });
  }

  // Toggle selection status for a photo.
  void _toggleSelection(File photo) {
    setState(() {
      if (_selectedPaths.contains(photo.path)) {
        _selectedPaths.remove(photo.path);
        if (_selectedPaths.isEmpty) _selectionMode = false;
      } else {
        _selectedPaths.add(photo.path);
        _selectionMode = true;
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedPaths.clear();
      _selectionMode = false;
    });
  }

  // Select all or deselect all photos.
  void _selectAllOrNone() {
    final allSelected = _selectedPaths.length == sortedPhotos.length;
    setState(() {
      if (allSelected) {
        _selectedPaths.clear();
        _selectionMode = false;
      } else {
        _selectedPaths = sortedPhotos.map((photo) => photo.path).toSet();
        _selectionMode = true;
      }
    });
  }

  // Helper: Check if all selected photos are favorites.
  bool _allSelectedAreFavorite() {
    final selectedPhotos =
        sortedPhotos.where((photo) => _selectedPaths.contains(photo.path));
    if (selectedPhotos.isEmpty) return false;
    return selectedPhotos.every((photo) => _favoritePaths.contains(photo.path));
  }

  // Toggle favorite status for all selected photos.
  void _toggleFavoriteForSelectedPhotos() {
    final selectedPhotos =
        sortedPhotos.where((photo) => _selectedPaths.contains(photo.path));
    final allAreFavorite =
        selectedPhotos.every((photo) => _favoritePaths.contains(photo.path));
    setState(() {
      for (final photo in selectedPhotos) {
        if (allAreFavorite) {
          _favoritePaths.remove(photo.path);
        } else {
          _favoritePaths.add(photo.path);
        }
      }
      // Clear selection after bulk update.
      _selectedPaths.clear();
      _selectionMode = false;
    });
  }

  // Delete selected photos.
  Future<void> _deleteSelectedPhotos() async {
    if (_selectedPaths.isEmpty) return;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Photos'),
          content: const Text(
              'Are you sure you want to delete the selected photos?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final photosToDelete = widget.photos
        .where((photo) => _selectedPaths.contains(photo.path))
        .toList();

    setState(() {
      widget.photos.removeWhere((photo) => _selectedPaths.contains(photo.path));
      _selectedPaths.clear();
      _selectionMode = false;
    });

    await widget.onSave();

    for (var photo in photosToDelete) {
      if (photo.existsSync()) {
        photo.deleteSync();
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selected photos deleted!')),
    );
  }

  // Share selected photos.
  Future<void> _shareSelectedPhotos() async {
    if (_selectedPaths.isEmpty) return;

    final filesToShare = widget.photos
        .where((photo) => _selectedPaths.contains(photo.path))
        .map((photo) => XFile(photo.path))
        .toList();

    try {
      await Share.shareXFiles(filesToShare, text: 'Check out these photos!');
      setState(() {
        _selectedPaths.clear();
        _selectionMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing photos: $e')),
      );
    }
  }

  // Generate a PDF from selected photos.
  Future<void> _generatePdf() async {
    if (_selectedPaths.isEmpty) return;

    // Show a loading indicator.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Container(
        color: Colors.black54,
        child: Center(
          child: Lottie.network(
            'https://assets10.lottiefiles.com/packages/lf20_jcikwtux.json',
            width: 650,
            height: 450,
            fit: BoxFit.fill,
          ),
        ),
      ),
    );

    try {
      await Future.wait([
        _generatePdfInternal(),
        Future.delayed(const Duration(seconds: 1)),
      ]);

      setState(() {
        _selectedPaths.clear();
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
      Navigator.pop(context); // Dismiss loading indicator.
    }
  }

  Future<void> _generatePdfInternal() async {
    final pdf = pw.Document();
    final selectedFiles = sortedPhotos
        .where((photo) => _selectedPaths.contains(photo.path))
        .toList();

    for (var file in selectedFiles) {
      final imageBytes = await _resizeImage(file.path);
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(
            child: pw.Image(image),
          ),
        ),
      );
    }

    final dir = Directory(widget.pdfsDirectory!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final pdfFile = File(
      '${dir.path}${Platform.pathSeparator}photos_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await pdfFile.writeAsBytes(await pdf.save());
    widget.onPdfGenerated(pdfFile);
  }

  Future<Uint8List> _resizeImage(String path, {int? quality}) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Failed to decode image.');
    }
    final List<int> compressed =
        img.encodeJpg(decoded, quality: quality ?? 100);
    return Uint8List.fromList(compressed);
  }

  // Take a photo using the device camera.
  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        final newFile = File(pickedFile.path);
        setState(() {
          widget.photos.add(newFile);
        });
        await widget.onSave();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo added!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking photo: $e')),
      );
    }
  }

  // Import photos via the provided callback.
  Future<void> _importPhotos() async {
    try {
      await widget.onImportPhotos();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photos imported!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing photos: $e')),
      );
    }
  }

  // Open full-screen image editor/viewer.
  Future<void> _openFullScreenImage(File photo) async {
    try {
      final updatedImage = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenImage(imageFile: photo),
        ),
      );

      if (updatedImage != null) {
        final index = widget.photos.indexWhere((p) => p.path == photo.path);
        if (index != -1) {
          setState(() {
            widget.photos[index] = updatedImage;
          });
          await widget.onSave();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening image: $e')),
      );
    }
  }
}
