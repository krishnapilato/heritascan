import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

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
  // Use file paths for selection to handle sorting changes.
  Set<String> _selectedPaths = {};
  bool _selectionMode = false;

  // Grid layout: 2 or 3 columns.
  int _gridColumns = 2;

  // Sorting option: 'date_desc', 'date_asc', 'name_asc', 'name_desc'
  String _sortOption = 'date_desc';

  // Returns a sorted copy of the photos list based on _sortOption.
  List<File> get sortedPhotos {
    List<File> list = List.from(widget.photos);
    switch (_sortOption) {
      case 'date_desc':
        list.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        break;
      case 'date_asc':
        list.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
        break;
      case 'name_asc':
        list.sort((a, b) => a.path
            .split(Platform.pathSeparator)
            .last
            .toLowerCase()
            .compareTo(b.path.split(Platform.pathSeparator).last.toLowerCase()));
        break;
      case 'name_desc':
        list.sort((a, b) => b.path
            .split(Platform.pathSeparator)
            .last
            .toLowerCase()
            .compareTo(a.path.split(Platform.pathSeparator).last.toLowerCase()));
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
      body: CustomScrollView(
        slivers: [
          // SliverAppBar with dynamic actions.
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            floating: false,
            expandedHeight: 120,
            elevation: 0,
            backgroundColor: theme.colorScheme.background,
            leading: _selectionMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _cancelSelection,
                    tooltip: 'Cancel Selection',
                  )
                : null,
            centerTitle: false,
            title: Text(
              _selectionMode
                  ? 'Selected (${_selectedPaths.length})'
                  : 'Images',
              style: TextStyle(
                fontSize: _selectionMode ? 18 : 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: _selectionMode
                ? [
                    IconButton(
                      icon: Icon(allSelected ? Icons.clear_all : Icons.select_all),
                      onPressed: _selectAllOrNone,
                      tooltip: allSelected ? 'Deselect All' : 'Select All',
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
                : [
                    IconButton(
                      icon: Icon(
                        _gridColumns == 2 ? Icons.grid_view_rounded : Icons.view_comfy,
                      ),
                      onPressed: _toggleGalleryLayout,
                      tooltip: 'Toggle Layout',
                    ),
                    // Sorting Popup Menu.
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
                    IconButton(
                      icon: const Icon(Icons.settings_rounded),
                      onPressed: () => Navigator.pushNamed(context, '/settings'),
                      tooltip: 'Settings',
                    ),
                  ],
            flexibleSpace: const FlexibleSpaceBar(
              titlePadding: EdgeInsets.zero,
            ),
          ),
          // Main body.
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
            SliverPadding(
              padding: const EdgeInsets.all(12.0),
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
                              ? Border.all(color: theme.colorScheme.primary, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                    color: theme.colorScheme.primary.withOpacity(0.4),
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
                              // Display photo.
                              Image.file(
                                photo,
                                fit: BoxFit.cover,
                                key: ValueKey(photo.path + (isSelected ? 'selected' : '')),
                                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                  if (wasSynchronouslyLoaded) return child;
                                  return AnimatedOpacity(
                                    opacity: frame == null ? 0 : 1,
                                    duration: const Duration(seconds: 1),
                                    child: child,
                                  );
                                },
                              ),
                              // Selection overlay.
                              if (isSelected)
                                Container(
                                  color: theme.colorScheme.primary.withOpacity(0.4),
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

  // Toggle selection status of a photo.
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

  // Delete selected photos from disk and update the list.
  Future<void> _deleteSelectedPhotos() async {
    if (_selectedPaths.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Photos'),
          content: const Text('Are you sure you want to delete the selected photos?'),
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

    final photosToDelete = widget.photos.where((photo) => _selectedPaths.contains(photo.path)).toList();

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

    // Show a loading animation.
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
      Navigator.pop(context); // Dismiss loading dialog.
    }
  }

  Future<void> _generatePdfInternal() async {
    final pdf = pw.Document();
    final selectedFiles = sortedPhotos.where((photo) => _selectedPaths.contains(photo.path)).toList();

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
    final List<int> compressed = img.encodeJpg(decoded, quality: quality ?? 100);
    return Uint8List.fromList(compressed);
  }

  // Open full-screen image editor/viewer.
  Future<void> _openFullScreenImage(File photo) async {
    try {
      final updatedImage = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenImage(
            imageFile: photo,
          ),
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