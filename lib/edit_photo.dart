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
    // Return the edited image file to the previous screen
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
                        style:
                            TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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