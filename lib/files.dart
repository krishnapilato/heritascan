import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:lottie/lottie.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Displays a list of generated PDFs with a modern sliver layout.
/// Each can be viewed, shared, or deleted.
class FilesScreen extends StatefulWidget {
  final List<File> pdfs;

  const FilesScreen({Key? key, required this.pdfs}) : super(key: key);

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  Set<int> _selectedIndices = {};
  bool _selectionMode = false;

  /// Toggles selection for a single PDF item.
  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        // Turn off selection mode if none are selected
        if (_selectedIndices.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedIndices.add(index);
        _selectionMode = true;
      }
    });
  }

  /// Toggles "Select All" vs. "Clear All" based on current selection state.
  void _toggleSelectAllOrNone() {
    final allSelected = _selectedIndices.length == widget.pdfs.length;
    setState(() {
      if (allSelected) {
        _selectedIndices.clear();
        _selectionMode = false;
      } else {
        _selectedIndices = Set.from(
          List.generate(widget.pdfs.length, (i) => i),
        );
        _selectionMode = true;
      }
    });
  }

  /// Shows a loading animation while attempting to open a PDF.
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

  /// Tries to open the PDF externally. If unsupported, opens in-app viewer.
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

  /// Tap event for PDF item
  void _onPdfTap(int index) {
    if (_selectionMode) {
      _toggleSelection(index);
    } else {
      _openPdf(widget.pdfs[index]);
    }
  }

  /// Long press triggers selection mode for PDF item
  void _onPdfLongPress(int index) {
    _toggleSelection(index);
  }

  /// Shows a confirmation dialog before deleting selected PDFs.
  Future<void> _confirmDeleteSelectedPdfs() async {
    final confirm = await showDialog<bool>(
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

  /// Deletes all currently selected PDFs from disk and updates local storage.
  Future<void> _deleteSelectedPdfs() async {
    if (_selectedIndices.isEmpty) return;

    final filesToDelete = _selectedIndices.map((i) => widget.pdfs[i]).toList();

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

  /// Shares all currently selected PDFs
  Future<void> _shareSelectedPdfs() async {
    if (_selectedIndices.isEmpty) return;

    final filesToShare = _selectedIndices
        .map((idx) => XFile(widget.pdfs[idx].path))
        .toList();

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

  /// Cancels selection mode entirely
  void _cancelSelection() {
    setState(() {
      _selectedIndices.clear();
      _selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemCount = widget.pdfs.length;
    final isEmpty = itemCount == 0;
    final allSelected = _selectedIndices.length == itemCount && itemCount > 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: false,
            expandedHeight: 100,
            centerTitle: false,
            backgroundColor: theme.colorScheme.background,
            elevation: 0,

            // Leading button to cancel selection if in selection mode
            leading: _selectionMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _cancelSelection,
                    tooltip: 'Cancel Selection',
                  )
                : null,

            // Title logic
            title: _selectionMode
                ? Text(
                    'Select(${_selectedIndices.length})',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,

            // Action buttons
            actions: _selectionMode
                ? [
                    // Select All / Deselect All
                    IconButton(
                      icon: Icon(allSelected ? Icons.clear_all : Icons.select_all),
                      onPressed: _selectAllOrNone,
                      tooltip: allSelected ? 'Deselect All' : 'Select All',
                    ),
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
                  ]
                : null,

            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
              title: !_selectionMode
                  ? Text(
                      'Files',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),

          // Body content
          if (isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'No PDFs available.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final file = widget.pdfs[index];
                  final isSelected = _selectedIndices.contains(index);
                  return _buildPdfTile(file, index, isSelected);
                },
                childCount: itemCount,
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a single tile representing a PDF file.
  Widget _buildPdfTile(File file, int index, bool isSelected) {
    final theme = Theme.of(context);
    final fileName = file.path.split('/').last;

    return GestureDetector(
      onTap: () => _onPdfTap(index),
      onLongPress: () => _onPdfLongPress(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: isSelected
            ? theme.colorScheme.primary.withOpacity(0.3)
            : Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
          title: Text(
            fileName,
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  /// Select All / Deselect All logic
  void _selectAllOrNone() {
    final allSelected = _selectedIndices.length == widget.pdfs.length;
    setState(() {
      if (allSelected) {
        _selectedIndices.clear();
        _selectionMode = false;
      } else {
        _selectedIndices = Set.from(
          List.generate(widget.pdfs.length, (i) => i),
        );
        _selectionMode = true;
      }
    });
  }
}

/// A simple PDF viewer screen using the flutter_pdfview package.
class PdfViewerScreen extends StatelessWidget {
  final String path;

  const PdfViewerScreen({Key? key, required this.path}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use a gradient or other background you like
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
                  swipeHorizontal: true,
                  autoSpacing: true,
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