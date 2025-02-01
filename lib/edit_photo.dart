import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_editor_plus/image_editor_plus.dart';

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
        // Overwrite the original file with the edited version
        await _editedImage.writeAsBytes(editedImageBytes);

        setState(() {
          _imageVersion++;
          // Clear image cache to force the updated file to reload
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image edited successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error editing image: $e')),
      );
    } finally {
      setState(() => _isEditing = false);
    }
  }

  /// Returns the edited image to the previous screen
  void _saveImage() {
    Navigator.pop(context, _editedImage);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // We wrap everything in a gradient background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFDE6262), Color(0xFFFFB88C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // SliverAppBar pinned at the top
              SliverAppBar(
                pinned: true,
                expandedHeight: 100,
                backgroundColor: Colors.transparent,
                elevation: 0,
                // If we are editing, we show "Editing..." in the title
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

              // Displays the image, filling the remaining space
              SliverFillRemaining(
                hasScrollBody: false,
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