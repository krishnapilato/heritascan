import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// A full-screen image viewer and editor with various editing options.
/// The UI follows Google Material guidelines.
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

  /// Stores the original image bytes to allow a "reset" operation.
  Uint8List? _originalImageBytes;

  @override
  void initState() {
    super.initState();
    _editedImage = widget.imageFile;
    // Initialize the original image bytes for reset
    widget.imageFile.readAsBytes().then((bytes) {
      setState(() {
        _originalImageBytes = bytes;
      });
    });
  }

  /// Updates the image file with new bytes and forces the UI to refresh.
  Future<void> _updateImage(Uint8List newBytes) async {
    await _editedImage.writeAsBytes(newBytes);
    setState(() {
      _imageVersion++;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
  }

  /// Launches the image editor.
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
        await _updateImage(editedImageBytes);
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
      await _updateImage(Uint8List.fromList(rotatedBytes));
      _showSnackBar('Image rotated successfully!');
    } catch (e) {
      _showSnackBar('Error rotating image: $e');
    }
  }

  /// Shares the image using the share_plus package.
  Future<void> _shareImage() async {
    try {
      await Share.shareXFiles(
        [XFile(_editedImage.path)],
        text: 'Check out this image!',
      );
    } catch (e) {
      _showSnackBar('Error sharing image: $e');
    }
  }

  /// Saves the image and returns to the previous screen.
  void _saveImage() => Navigator.pop(context, _editedImage);

  /// Returns the file name.
  String get _fileName => _editedImage.path.split(Platform.pathSeparator).last;

  /// Returns the formatted last modified date.
  String get _lastModified {
    final modTime = _editedImage.lastModifiedSync();
    return DateFormat('yyyy-MM-dd HH:mm').format(modTime);
  }

  /// Displays a SnackBar with the given message, adapting to the theme.
  void _showSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: Theme.of(context).snackBarTheme.contentTextStyle ??
            const TextStyle(fontSize: 16),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Theme.of(context).snackBarTheme.backgroundColor,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Shows file details in a draggable bottom sheet.
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
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
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
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last modified: $_lastModified',
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Applies a filter to the image.
  Future<void> _applyFilter(String filter) async {
    try {
      Uint8List bytes = await _editedImage.readAsBytes();
      img.Image? original = img.decodeImage(bytes);
      if (original == null) {
        _showSnackBar('Error decoding image for filter.');
        return;
      }
      img.Image filtered;
      switch (filter) {
        case 'grayscale':
          filtered = img.grayscale(original);
          break;
        case 'sepia':
          filtered = img.sepia(original);
          break;
        case 'invert':
          filtered = img.invert(original);
          break;
        default:
          _showSnackBar('Unknown filter');
          return;
      }
      List<int> filteredBytes = img.encodeJpg(filtered);
      await _updateImage(Uint8List.fromList(filteredBytes));
      _showSnackBar('Filter applied: $filter');
    } catch (e) {
      _showSnackBar('Error applying filter: $e');
    }
  }

  /// Displays a dialog to select a filter.
  void _showFilterOptions() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Filter"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text("Grayscale"),
                onTap: () {
                  Navigator.pop(context);
                  _applyFilter('grayscale');
                },
              ),
              ListTile(
                title: const Text("Sepia"),
                onTap: () {
                  Navigator.pop(context);
                  _applyFilter('sepia');
                },
              ),
              ListTile(
                title: const Text("Invert"),
                onTap: () {
                  Navigator.pop(context);
                  _applyFilter('invert');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Mirrors the image horizontally.
  Future<void> _mirrorImage() async {
    try {
      Uint8List bytes = await _editedImage.readAsBytes();
      img.Image? original = img.decodeImage(bytes);
      if (original == null) {
        _showSnackBar('Error decoding image for mirror.');
        return;
      }
      img.Image mirrored = img.flipHorizontal(original);
      List<int> mirroredBytes = img.encodeJpg(mirrored);
      await _updateImage(Uint8List.fromList(mirroredBytes));
      _showSnackBar('Image mirrored successfully!');
    } catch (e) {
      _showSnackBar('Error mirroring image: $e');
    }
  }

  /// Crops the image using the image editor.
  Future<void> _cropImage() async {
    setState(() => _isEditing = true);
    try {
      Uint8List imageData = await _editedImage.readAsBytes();
      final croppedImageBytes = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEditor(image: imageData),
        ),
      );
      if (croppedImageBytes is Uint8List) {
        await _updateImage(croppedImageBytes);
        _showSnackBar('Image cropped successfully!');
      }
    } catch (e) {
      _showSnackBar('Error cropping image: $e');
    } finally {
      setState(() => _isEditing = false);
    }
  }

  /// Adjusts the brightness of the image.
  Future<void> _adjustBrightness(double brightness) async {
    try {
      Uint8List bytes = await _editedImage.readAsBytes();
      img.Image? original = img.decodeImage(bytes);
      if (original == null) {
        _showSnackBar('Error decoding image for brightness adjustment.');
        return;
      }
      img.Image brightened = img.adjustColor(original, brightness: brightness);
      List<int> newBytes = img.encodeJpg(brightened);
      await _updateImage(Uint8List.fromList(newBytes));
      _showSnackBar('Brightness adjusted!');
    } catch (e) {
      _showSnackBar('Error adjusting brightness: $e');
    }
  }

  /// Displays a dialog with a slider to adjust brightness.
  void _showBrightnessDialog() {
    double currentBrightness = 0.0;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Adjust Brightness"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: currentBrightness,
                    min: -1.0,
                    max: 1.0,
                    divisions: 20,
                    label: currentBrightness.toStringAsFixed(2),
                    onChanged: (value) {
                      setState(() {
                        currentBrightness = value;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _adjustBrightness(currentBrightness);
              },
              child: const Text("Apply"),
            ),
          ],
        );
      },
    );
  }

  /// Resets the image to its original state.
  Future<void> _resetImage() async {
    if (_originalImageBytes != null) {
      await _editedImage.writeAsBytes(_originalImageBytes!);
      setState(() {
        _imageVersion++;
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      });
      _showSnackBar('Image reset to original.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            Colors.black.withOpacity(0.3),
        elevation: Theme.of(context).appBarTheme.elevation ?? 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).iconTheme.color ?? Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _fileName,
          style: Theme.of(context).appBarTheme.titleTextStyle ??
              Theme.of(context).textTheme.titleLarge ??
              const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.share,
              color: Theme.of(context).iconTheme.color ?? Colors.white,
            ),
            onPressed: _shareImage,
            tooltip: 'Share',
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).iconTheme.color ?? Colors.white,
            ),
            tooltip: 'More Options',
            onSelected: (String action) {
              switch (action) {
                case 'edit':
                  _launchEditor();
                  break;
                case 'rotate':
                  _rotateImage();
                  break;
                case 'details':
                  _showDetails();
                  break;
                case 'filter':
                  _showFilterOptions();
                  break;
                case 'mirror':
                  _mirrorImage();
                  break;
                case 'crop':
                  _cropImage();
                  break;
                case 'brightness':
                  _showBrightnessDialog();
                  break;
                case 'reset':
                  _resetImage();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(
                    Icons.edit,
                    color: Theme.of(context).iconTheme.color ?? Colors.white,
                  ),
                  title: Text(
                    'Edit Image',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'rotate',
                child: ListTile(
                  leading: Icon(
                    Icons.rotate_right,
                    color: Theme.of(context).iconTheme.color ?? Colors.white,
                  ),
                  title: Text(
                    'Rotate Image',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'details',
                child: ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: Theme.of(context).iconTheme.color ?? Colors.white,
                  ),
                  title: Text(
                    'File Details',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'filter',
                child: ListTile(
                  leading: Icon(
                    Icons.filter,
                    color: Theme.of(context).iconTheme.color ?? Colors.white,
                  ),
                  title: Text(
                    'Apply Filter',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'mirror',
                child: ListTile(
                  leading: Icon(
                    Icons.flip,
                    color: Theme.of(context).iconTheme.color ?? Colors.white,
                  ),
                  title: Text(
                    'Mirror Image',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'crop',
                child: ListTile(
                  leading: Icon(
                    Icons.crop,
                    color: Theme.of(context).iconTheme.color ?? Colors.white,
                  ),
                  title: Text(
                    'Crop Image',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'brightness',
                child: ListTile(
                  leading: Icon(
                    Icons.brightness_6,
                    color: Theme.of(context).iconTheme.color ?? Colors.white,
                  ),
                  title: Text(
                    'Adjust Brightness',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: Icon(
                    Icons.refresh,
                    color: Theme.of(context).iconTheme.color ?? Colors.white,
                  ),
                  title: Text(
                    'Reset Image',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      // Body with full-screen InteractiveViewer wrapped with a GestureDetector for vertical swipes.
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragEnd: (details) {
                final velocity = details.velocity.pixelsPerSecond.dy;
                // If user swipes up (negative velocity), show details.
                if (velocity < -500) {
                  _showDetails();
                }
                // If user swipes down (positive velocity), dismiss the screen.
                else if (velocity > 500) {
                  Navigator.pop(context);
                }
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: _isEditing
                    ? const Center(child: CircularProgressIndicator())
                    : InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 5.0,
                        child: Image.file(
                          _editedImage,
                          key: ValueKey(_imageVersion),
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}