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
  // Selection
  Set<int> _selectedIndices = {};
  bool _selectionMode = false;

  // Grid layout: 2 columns or 3 columns
  int _gridColumns = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allSelected = _selectedIndices.length == widget.photos.length;
    final isEmpty = widget.photos.isEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
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
            title: _selectionMode
                ? Text(
                    'Selected (${_selectedIndices.length})',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
            actions: [
              if (_selectionMode) ...[
                // Select/Deselect All
                IconButton(
                  icon: Icon(
                    allSelected ? Icons.clear_all : Icons.select_all,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: _selectAllOrNone,
                  tooltip: allSelected ? 'Deselect All' : 'Select All',
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: theme.colorScheme.primary),
                  onPressed: _deleteSelectedPhotos,
                  tooltip: 'Delete',
                ),
                IconButton(
                  icon: Icon(Icons.share, color: theme.colorScheme.primary),
                  onPressed: _shareSelectedPhotos,
                  tooltip: 'Share',
                ),
                IconButton(
                  icon: Icon(Icons.picture_as_pdf, color: theme.colorScheme.primary),
                  onPressed: _generatePdf,
                  tooltip: 'Generate PDF',
                ),
              ] else ...[
                // Toggle layout button (2 or 3 columns)
                IconButton(
                  icon: Icon(
                    _gridColumns == 2 ? Icons.grid_3x3_outlined : Icons.grid_view,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: _toggleGalleryLayout,
                  tooltip: 'Toggle Layout',
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  color: theme.colorScheme.primary,
                  onPressed: () {
                    Navigator.pushNamed(context, '/settings');
                  },
                  tooltip: 'Settings',
                ),
              ],
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
              title: (!_selectionMode)
                  ? Text(
                      'Photos',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),

          // Body
          if (isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'Tap the camera button to take a photo\nor import from gallery.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
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
                    final isSelected = _selectedIndices.contains(index);
                    final photo = widget.photos[index];
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
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.25),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ]
                              : [
                                  // Subtle shadow in light mode
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
                              // Photo image
                              Image.file(
                                photo,
                                fit: BoxFit.cover,
                                key: ValueKey(
                                  photo.path + (isSelected ? 'selected' : ''),
                                ),
                                frameBuilder: (context, child, frame,
                                    wasSynchronouslyLoaded) {
                                  if (wasSynchronouslyLoaded) {
                                    return child;
                                  }
                                  return AnimatedOpacity(
                                    opacity: frame == null ? 0 : 1,
                                    duration: const Duration(seconds: 1),
                                    child: child,
                                  );
                                },
                              ),

                              // Overlay if selected
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
                  childCount: widget.photos.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Toggles 2-col or 3-col gallery layout.
  void _toggleGalleryLayout() {
    setState(() {
      _gridColumns = (_gridColumns == 2) ? 3 : 2;
    });
  }

  // Selection Logic
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
        _selectedIndices = Set.from(
          List.generate(widget.photos.length, (i) => i),
        );
        _selectionMode = true;
      }
    });
  }

  // Deletion
  void _deleteSelectedPhotos() {
    if (_selectedIndices.isEmpty) return;

    final photosToDelete =
        _selectedIndices.map((i) => widget.photos[i]).toList();

    setState(() {
      widget.photos.removeWhere((photo) => photosToDelete.contains(photo));
      _selectedIndices.clear();
      _selectionMode = false;
    });

    widget.onSave(); // Persist updated photos list

    // Delete files from disk
    for (var photo in photosToDelete) {
      if (photo.existsSync()) {
        photo.deleteSync();
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selected photos deleted!')),
    );
  }

  // Sharing
  void _shareSelectedPhotos() async {
    if (_selectedIndices.isEmpty) return;

    final filesToShare = _selectedIndices.map((idx) {
      return XFile(widget.photos[idx].path);
    }).toList();

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

  // PDF Generation
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
        Future.delayed(const Duration(seconds: 1)), // Brief delay for animation
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
      Navigator.pop(context); // remove loading dialog
    }
  }

  Future<void> _generatePdfInternal() async {
    final pdf = pw.Document();
    final List<int> indices = _selectedIndices.toList()..sort();

    for (var index in indices) {
      final imageBytes = await _resizeImage(widget.photos[index].path);
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

    final file = File(
      '${dir.path}/photos_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    widget.onPdfGenerated(file);
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

  // Opens full-screen image editor/viewer
  Future<void> _openFullScreenImage(int index) async {
    try {
      final updatedImage = await Navigator.push<File?>(
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
}