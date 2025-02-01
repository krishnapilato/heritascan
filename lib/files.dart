import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
// ignore: depend_on_referenced_packages
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FilesScreen extends StatefulWidget {
  final List<File> pdfs;

  const FilesScreen({Key? key, required this.pdfs}) : super(key: key);

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  Set<int> _selectedIndices = {};
  bool _selectionMode = false;

  // Toggles selection for a single PDF item.
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

  // Toggles "Select All" vs. "Clear All" based on current selection state.
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

  // Shows a loading animation while attempting to open a PDF.
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

  // Tries to open the PDF externally. If unsupported, opens in-app viewer.
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
            builder: (_) => PdfViewerScreen(path: file.path),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening PDF: $e')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(path: file.path),
        ),
      );
    }
  }

  // Tap event for PDF item
  void _onPdfTap(int index) {
    if (_selectionMode) {
      _toggleSelection(index);
    } else {
      _openPdf(widget.pdfs[index]);
    }
  }

  // Long press triggers selection mode for PDF item
  void _onPdfLongPress(int index) {
    _toggleSelection(index);
  }

  // Shows a confirmation dialog before deleting selected PDFs.
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

  // Deletes all currently selected PDFs from disk and updates local storage.
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

      await _updateSharedPrefs();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected PDFs deleted!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting PDFs: $e')),
      );
    }
  }

  // Shares all currently selected PDFs
  Future<void> _shareSelectedPdfs() async {
    if (_selectedIndices.isEmpty) return;
    final filesToShare = _selectedIndices.map((idx) => XFile(widget.pdfs[idx].path)).toList();

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

  // Cancels selection mode entirely
  void _cancelSelection() {
    setState(() {
      _selectedIndices.clear();
      _selectionMode = false;
    });
  }

  // Renames a single PDF file on disk and updates the list & shared prefs.
  Future<void> _renamePdf(File oldFile, String newName, int index) async {
    if (newName.trim().isEmpty) return;

    // Ensure the new name ends with ".pdf"
    if (!newName.toLowerCase().endsWith('.pdf')) {
      newName = '${newName.trim()}.pdf';
    }

    final directory = oldFile.parent;
    final newPath = '${directory.path}/$newName';

    try {
      final newFile = await oldFile.rename(newPath);
      setState(() {
        widget.pdfs[index] = newFile;
      });
      await _updateSharedPrefs();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renamed to $newName')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error renaming file: $e')),
      );
    }
  }

  // Opens a dialog allowing the user to enter a new name for the PDF.
  Future<void> _showRenameDialog(File file, int index) async {
    final oldName = file.path.split('/').last;
    final controller = TextEditingController(text: oldName.replaceAll('.pdf', ''));

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename PDF'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New name (without .pdf)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, controller.text);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null) {
      await _renamePdf(file, newName, index);
    }
  }

  // Updates shared prefs so it matches the current 'widget.pdfs'.
  Future<void> _updateSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final pdfPaths = widget.pdfs.map((file) => file.path).toList();
    await prefs.setStringList('pdfs', pdfPaths);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemCount = widget.pdfs.length;
    final isEmpty = itemCount == 0;
    final allSelected = _selectedIndices.length == itemCount && itemCount > 0;

    return Scaffold(
      // We use a CustomScrollView + SliverAppBar pattern.
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: false,
            expandedHeight: 90,
            centerTitle: false,
            backgroundColor: theme.colorScheme.background,
            elevation: 1,

            leading: _selectionMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _cancelSelection,
                    tooltip: 'Cancel Selection',
                  )
                : null,

            title: _selectionMode
                ? Text(
                    'Selected (${_selectedIndices.length})',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,

            actions: _selectionMode
                ? [
                    IconButton(
                      icon: Icon(
                        allSelected ? Icons.clear_all : Icons.select_all,
                      ),
                      onPressed: _toggleSelectAllOrNone,
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
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              // Only show the main title if not in selection mode
              title: !_selectionMode
                  ? Text(
                      'Files',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
          ),

          if (isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'No PDFs available.',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.disabledColor,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final file = widget.pdfs[index];
                  final isSelected = _selectedIndices.contains(index);
                  return _buildPdfCard(file, index, isSelected);
                },
                childCount: itemCount,
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a single card-like tile representing a PDF file,
  /// with name, size, modified date, plus PDF icon + trailing popup menu.
  Widget _buildPdfCard(File file, int index, bool isSelected) {
    final theme = Theme.of(context);
    final fileName = file.path.split('/').last;

    // Gather file metadata
    final fileStat = file.statSync();
    final fileSize = _formatFileSize(fileStat.size);
    final modifiedDate = fileStat.modified;
    String formattedDate = 'Unknown';
    if (modifiedDate != null) {
      formattedDate = DateFormat('dd-MM-yyyy HH:mm a').format(modifiedDate);
    }

    // Decide the default card color based on the theme (dark or light).
    final baseCardColor = theme.cardColor;
    final selectedColor = theme.colorScheme.primary.withOpacity(0.12);

    return GestureDetector(
      onTap: () => _onPdfTap(index),
      onLongPress: () => _onPdfLongPress(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        // Use a Card for a more Material-like look with rounded corners.
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : baseCardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (theme.brightness == Brightness.light)
              BoxShadow(
                color: isSelected
                    ? theme.colorScheme.primary.withOpacity(0.2)
                    : Colors.black12,
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: const CircleAvatar(
            backgroundColor: Colors.transparent,
            child: Icon(Icons.picture_as_pdf, color: Colors.red),
          ),
          title: Text(
            fileName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '$fileSize • $formattedDate',
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show check icon if selected
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                  ),
                ),
              // Popup menu button for rename
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'rename') {
                    _showRenameDialog(file, index);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'rename',
                    child: Text('Rename'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Format file sizes in a readable manner
  String _formatFileSize(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(2)} GB';
    } else if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    } else if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }
}

// Simple PDF viewer screen with a gradient background
class PdfViewerScreen extends StatelessWidget {
  final String path;

  const PdfViewerScreen({Key? key, required this.path}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use the same or similar gradient background
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