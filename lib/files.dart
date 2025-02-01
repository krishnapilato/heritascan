import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:lottie/lottie.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Displays a list of generated PDFs. Each can be viewed, shared, or deleted.
class FilesScreen extends StatefulWidget {
  final List<File> pdfs;

  const FilesScreen({Key? key, required this.pdfs}) : super(key: key);

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  Set<int> _selectedIndices = {};
  bool _selectionMode = false;

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

  void _showLoadingDialog() {
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
  }

  Future<void> _openPdf(File file) async {
    _showLoadingDialog();

    try {
      if (!await file.exists()) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File does not exist.')),
        );
        return;
      }

      final result = await OpenFilex.open(file.path);
      Navigator.pop(context);

      if (result.type != ResultType.done) {
        // Fallback to in-app PDF viewer
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(path: file.path),
          ),
        );
      }
    } catch (e) {
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

  void _onPdfTap(int index) {
    if (_selectionMode) {
      _toggleSelection(index);
    } else {
      _openPdf(widget.pdfs[index]);
    }
  }

  void _onPdfLongPress(int index) {
    _toggleSelection(index);
  }

  Future<void> _confirmDeleteSelectedPdfs() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete PDFs'),
        content: const Text('Are you sure you want to delete the selected PDFs?'),
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

  Future<void> _deleteSelectedPdfs() async {
    if (_selectedIndices.isEmpty) return;

    List<File> filesToDelete = [];
    for (var idx in _selectedIndices) {
      filesToDelete.add(widget.pdfs[idx]);
    }

    try {
      for (var file in filesToDelete) {
        if (await file.exists()) {
          await file.delete();
        }
      }

      setState(() {
        widget.pdfs.removeWhere((pdf) => filesToDelete.contains(pdf));
        _selectedIndices.clear();
        _selectionMode = false;
      });

      final prefs = await SharedPreferences.getInstance();
      final pdfPaths = widget.pdfs.map((file) => file.path).toList();
      await prefs.setStringList('pdfs', pdfPaths);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected PDFs deleted!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting PDFs: $e')),
      );
    }
  }

  Future<void> _shareSelectedPdfs() async {
    if (_selectedIndices.isEmpty) return;

    List<XFile> filesToShare = [];
    for (var idx in _selectedIndices) {
      filesToShare.add(XFile(widget.pdfs[idx].path));
    }

    try {
      await Share.shareXFiles(filesToShare, text: 'Check out these PDFs!');
      setState(() {
        _selectedIndices.clear();
        _selectionMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing PDFs: $e')),
      );
    }
  }

  void _cancelSelection() {
    setState(() {
      _selectedIndices.clear();
      _selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _selectionMode
          ? AppBar(
              title: Text('${_selectedIndices.length} Selected'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _shareSelectedPdfs,
                  tooltip: 'Share',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _confirmDeleteSelectedPdfs,
                  tooltip: 'Delete',
                ),
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
              centerTitle: false,
              backgroundColor: Colors.transparent,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Files',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
                ? [const Color(0xFF262626), const Color(0xFF3A3A3A)]
                : [const Color(0xFFFDFDFD), const Color(0xFFEFEFEF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: widget.pdfs.isEmpty
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
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.color,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.white)
                            : null,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// A simple PDF viewer screen using the flutter_pdfview package.
class PdfViewerScreen extends StatelessWidget {
  final String path;

  const PdfViewerScreen({Key? key, required this.path}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFBBD2C5), Color(0xFF536976)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('View PDF'),
                backgroundColor: Colors.transparent,
              ),
              Expanded(
                child: PDFView(
                  filePath: path,
                  enableSwipe: true,
                  nightMode: false,
                  swipeHorizontal: true,
                  autoSpacing: false,
                  pageFling: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}