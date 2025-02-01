import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:intl/intl.dart';
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

  void _saveImage() => Navigator.pop(context, _editedImage);

  String get _fileName => _editedImage.path.split('/').last;

  String get _lastModified {
    final modTime = _editedImage.lastModifiedSync();
    return DateFormat('yyyy-MM-dd HH:mm').format(modTime);
  }

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
              SliverAppBar(
                pinned: true,
                expandedHeight: 90,
                backgroundColor: Colors.black.withOpacity(0.3),
                elevation: 0,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2)
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
                      : Text(
                          _fileName,
                          key: ValueKey('FileName'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                ),
                actions: _isEditing
                    ? []
                    : [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 26, color: Colors.white),
                          onPressed: _launchEditor,
                          tooltip: 'Edit Image',
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle, size: 26, color: Colors.greenAccent),
                          onPressed: _saveImage,
                          tooltip: 'Save',
                        ),
                      ],
              ),
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
                              : Image.file(
                                  _editedImage,
                                  key: ValueKey(_imageVersion),
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last modified: $_lastModified',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
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