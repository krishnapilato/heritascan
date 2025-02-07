import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart'
    as img; // For image manipulation (e.g., rotation)
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:intl/intl.dart';
import 'package:marquee/marquee.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

class FullScreenImage extends StatefulWidget {
  final File imageFile;

  const FullScreenImage({Key? key, required this.imageFile}) : super(key: key);

  @override
  _FullScreenImageState createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  late File _editedImage;
  bool _isEditing = false;
  int _imageVersion = 0;

  @override
  void initState() {
    super.initState();
    _editedImage = widget.imageFile;
  }

  /// Launches the image editor and updates the image.
  Future<void> _launchEditor() async {
    setState(() => _isEditing = true);
    try {
      Uint8List imageData = await _editedImage.readAsBytes();
      final editedImageBytes = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEditor(image: imageData),
        ),
      );
      if (editedImageBytes is Uint8List) {
        await _editedImage.writeAsBytes(editedImageBytes);
        setState(() {
          _imageVersion++;
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        });
        _showSnackBar('Image edited successfully!');
      }
    } catch (e) {
      _showSnackBar('Error editing image: $e');
    } finally {
      setState(() => _isEditing = false);
    }
  }

  /// Rotates the image 90° clockwise.
  Future<void> _rotateImage() async {
    try {
      Uint8List bytes = await _editedImage.readAsBytes();
      img.Image? original = img.decodeImage(bytes);
      if (original == null) {
        _showSnackBar('Error decoding image for rotation.');
        return;
      }
      img.Image rotated = img.copyRotate(original, angle: 90);
      List<int> rotatedBytes = img.encodeJpg(rotated);
      await _editedImage.writeAsBytes(rotatedBytes);
      setState(() {
        _imageVersion++;
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      });
      _showSnackBar('Image rotated successfully!');
    } catch (e) {
      _showSnackBar('Error rotating image: $e');
    }
  }

  /// Shares the current image.
  Future<void> _shareImage() async {
    try {
      await Share.shareXFiles([XFile(_editedImage.path)],
          text: 'Check out this image!');
    } catch (e) {
      _showSnackBar('Error sharing image: $e');
    }
  }

  /// Saves the image and returns it.
  void _saveImage() => Navigator.pop(context, _editedImage);

  /// Returns the file name.
  String get _fileName => _editedImage.path.split(Platform.pathSeparator).last;

  /// Returns the formatted last modified date.
  String get _lastModified {
    final modTime = _editedImage.lastModifiedSync();
    return DateFormat('yyyy-MM-dd HH:mm').format(modTime);
  }

  /// Displays a SnackBar with [message].
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
      ),
    );
  }

  /// Shows file details in a modern, draggable bottom sheet.
  void _showDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: scrollController,
                shrinkWrap: true,
                children: [
                  // Drag indicator
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _fileName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last modified: $_lastModified',
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Additional details can be added here
                ],
              ),
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keep your dark gradient background.
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1E1E), Color(0xFF444444)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // ---------------- Interactive Image Viewer ----------------
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: _isEditing
                      ? Shimmer.fromColors(
                          baseColor: Colors.grey[700]!,
                          highlightColor: Colors.grey[500]!,
                          child: Container(
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        )
                      : InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 3.0,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 300,
                              maxHeight: 300,
                            ),
                            child: Image.file(
                              _editedImage,
                              key: ValueKey(_imageVersion),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                ),
              ),
              // ---------------- Custom Transparent Top AppBar ----------------
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppBar(
                  backgroundColor: Colors.black.withOpacity(0.3),
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: SizedBox(
                    height: 24,
                    child: Marquee(
                      text: _fileName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      scrollAxis: Axis.horizontal,
                      blankSpace: 20.0,
                      velocity: 30.0,
                      pauseAfterRound: const Duration(seconds: 1),
                      startPadding: 10.0,
                      accelerationDuration: const Duration(seconds: 1),
                      accelerationCurve: Curves.linear,
                      decelerationDuration: const Duration(milliseconds: 500),
                      decelerationCurve: Curves.easeOut,
                    ),
                  ),
                  actions: [
                    // All functionalities are now in a single popup menu.
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      tooltip: 'Options',
                      onSelected: (String action) {
                        switch (action) {
                          case 'edit':
                            _launchEditor();
                            break;
                          case 'rotate':
                            _rotateImage();
                            break;
                          case 'share':
                            _shareImage();
                            break;
                          case 'save':
                            _saveImage();
                            break;
                          case 'details':
                            _showDetails();
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Edit Image'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'rotate',
                          child: ListTile(
                            leading: Icon(Icons.rotate_right),
                            title: Text('Rotate Image'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: ListTile(
                            leading: Icon(Icons.share),
                            title: Text('Share Image'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'save',
                          child: ListTile(
                            leading: Icon(Icons.check_circle),
                            title: Text('Save Image'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'details',
                          child: ListTile(
                            leading: Icon(Icons.info_outline),
                            title: Text('File Details'),
                          ),
                        ),
                      ],
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
