import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img; // For image manipulation (e.g., rotation)
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:intl/intl.dart';
import 'package:marquee/marquee.dart';
import 'package:share_plus/share_plus.dart'; // For sharing images
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

  /// Launches the image editor using [ImageEditor] and updates the image.
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
          // Clear the image cache to force reloading.
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

  /// Rotates the image 90 degrees clockwise.
  Future<void> _rotateImage() async {
    try {
      Uint8List bytes = await _editedImage.readAsBytes();
      img.Image? original = img.decodeImage(bytes);
      if (original == null) {
        _showSnackBar('Error decoding image for rotation.');
        return;
      }
      // Rotate the image 90 degrees clockwise.
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

  /// Shares the current image using the system share sheet.
  Future<void> _shareImage() async {
    try {
      await Share.shareXFiles([XFile(_editedImage.path)], text: 'Check out this image!');
    } catch (e) {
      _showSnackBar('Error sharing image: $e');
    }
  }

  /// Saves the image and returns it to the previous screen.
  void _saveImage() => Navigator.pop(context, _editedImage);

  /// Extracts the file name from the image path.
  String get _fileName =>
      _editedImage.path.split(Platform.pathSeparator).last;

  /// Formats the last modified date of the image.
  String get _lastModified {
    final modTime = _editedImage.lastModifiedSync();
    return DateFormat('yyyy-MM-dd HH:mm').format(modTime);
  }

  /// Displays a SnackBar with the provided [message].
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Gradient background for an enhanced visual appearance.
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1E1E), Color(0xFF444444)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // SliverAppBar with dynamic title and new action buttons.
              SliverAppBar(
                pinned: true,
                expandedHeight: 90,
                backgroundColor: Colors.black.withOpacity(0.3),
                elevation: 0,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                  ),
                ),
                title: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isEditing
                      ? const Text(
                          'Editing...',
                          key: ValueKey('Editing...'),
                          style: TextStyle(fontSize: 20, color: Colors.grey),
                        )
                      : SizedBox(
                          key: const ValueKey('FileName'),
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
                            decelerationDuration:
                                const Duration(milliseconds: 500),
                            decelerationCurve: Curves.easeOut,
                          ),
                        ),
                ),
                actions: _isEditing
                    ? []
                    : [
                        IconButton(
                          icon: const Icon(Icons.edit,
                              size: 26, color: Colors.white),
                          onPressed: _launchEditor,
                          tooltip: 'Edit Image',
                        ),
                        IconButton(
                          icon: const Icon(Icons.rotate_right,
                              size: 26, color: Colors.white),
                          onPressed: _rotateImage,
                          tooltip: 'Rotate Image',
                        ),
                        IconButton(
                          icon: const Icon(Icons.share,
                              size: 26, color: Colors.white),
                          onPressed: _shareImage,
                          tooltip: 'Share Image',
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle,
                              size: 26, color: Colors.greenAccent),
                          onPressed: _saveImage,
                          tooltip: 'Save',
                        ),
                      ],
              ),
              // Display area for the image.
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
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
                                  child: Center(
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
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last modified: $_lastModified',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
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