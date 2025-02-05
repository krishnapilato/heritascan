import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Load saved PDF file paths from shared preferences.
  final pdfPaths = prefs.getStringList('pdfs') ?? [];
  final pdfFiles = pdfPaths.map((path) => File(path)).toList();
  runApp(MyApp(pdfs: pdfFiles));
}

class MyApp extends StatelessWidget {
  final List<File> pdfs;
  const MyApp({Key? key, required this.pdfs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: FilesScreen(pdfs: pdfs),
    );
  }
}

class FilesScreen extends StatefulWidget {
  final List<File> pdfs;
  const FilesScreen({Key? key, required this.pdfs}) : super(key: key);

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  // Selection now stores file paths (to remain consistent across filters/sorts)
  Set<String> _selectedPaths = {};
  bool _selectionMode = false;
  bool _showSearch = false;
  bool _showFavoritesOnly = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Sorting option: 'name', 'date', 'size'
  String _sortOption = 'name';

  // Set to store favorite PDF file paths.
  Set<String> _favoritePdfPaths = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  // Load favorites from SharedPreferences.
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoritePdfPaths = prefs.getStringList('favoritePdfs')?.toSet() ?? {};
    });
  }

  // Update favorites in SharedPreferences.
  Future<void> _updateFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoritePdfs', _favoritePdfPaths.toList());
  }

  // Filter PDFs based on search query.
  List<File> get _filteredPdfs {
    if (_searchQuery.isEmpty) return widget.pdfs;
    return widget.pdfs.where((file) {
      final fileName = file.path.split(Platform.pathSeparator).last.toLowerCase();
      return fileName.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // Final list: apply favorites filter and sorting.
  List<File> get _finalPdfs {
    List<File> list = _filteredPdfs;
    if (_showFavoritesOnly) {
      list = list.where((file) => _favoritePdfPaths.contains(file.path)).toList();
    }
    list.sort((a, b) {
      switch (_sortOption) {
        case 'name':
          return a.path.split(Platform.pathSeparator).last.toLowerCase().compareTo(
              b.path.split(Platform.pathSeparator).last.toLowerCase());
        case 'date':
          return b.statSync().modified.compareTo(a.statSync().modified);
        case 'size':
          return b.statSync().size.compareTo(a.statSync().size);
        default:
          return 0;
      }
    });
    return list;
  }

  // Toggle selection for a given file.
  void _toggleSelection(String filePath) {
    setState(() {
      if (_selectedPaths.contains(filePath)) {
        _selectedPaths.remove(filePath);
      } else {
        _selectedPaths.add(filePath);
      }
      _selectionMode = _selectedPaths.isNotEmpty;
    });
  }

  // Toggle "Select All" or "Deselect All".
  void _toggleSelectAllOrNone() {
    final allSelected = _selectedPaths.length == _finalPdfs.length;
    setState(() {
      if (allSelected) {
        _selectedPaths.clear();
      } else {
        _selectedPaths = _finalPdfs.map((file) => file.path).toSet();
      }
    });
  }

  // Toggle favorite status for a file.
  void _toggleFavorite(File file) {
    setState(() {
      if (_favoritePdfPaths.contains(file.path)) {
        _favoritePdfPaths.remove(file.path);
      } else {
        _favoritePdfPaths.add(file.path);
      }
    });
    _updateFavorites();
  }

  // Show a loading dialog with a Lottie animation.
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

  // Open the PDF file externally. If not supported, fall back to in-app PDF viewer.
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
        // Fallback to in-app viewer.
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

  // Tap event for a PDF item.
  void _onPdfTap(File file) {
    if (_selectionMode) {
      _toggleSelection(file.path);
    } else {
      _openPdf(file);
    }
  }

  // Long press triggers selection mode.
  void _onPdfLongPress(File file) {
    _toggleSelection(file.path);
  }

  // Show confirmation dialog before deleting selected PDFs.
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _deleteSelectedPdfs();
    }
  }

  // Delete all selected PDFs from disk and update shared preferences.
  Future<void> _deleteSelectedPdfs() async {
    if (_selectedPaths.isEmpty) return;
    final filesToDelete =
        _finalPdfs.where((file) => _selectedPaths.contains(file.path)).toList();
    try {
      for (var file in filesToDelete) {
        if (await file.exists()) {
          await file.delete();
        }
      }
      setState(() {
        // Remove deleted files from the master list.
        widget.pdfs.removeWhere((pdf) => _selectedPaths.contains(pdf.path));
        _selectedPaths.clear();
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

  // Share selected PDFs.
  Future<void> _shareSelectedPdfs() async {
    if (_selectedPaths.isEmpty) return;
    final filesToShare = _finalPdfs
        .where((file) => _selectedPaths.contains(file.path))
        .map((file) => XFile(file.path))
        .toList();
    try {
      await Share.shareXFiles(filesToShare, text: 'Check out these PDFs!');
      setState(() {
        _selectedPaths.clear();
        _selectionMode = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing PDFs: $e')),
      );
    }
  }

  // Cancel selection mode.
  void _cancelSelection() {
    setState(() {
      _selectedPaths.clear();
      _selectionMode = false;
    });
  }

  // Rename a PDF file on disk and update the list and shared preferences.
  Future<void> _renamePdf(File oldFile, String newName) async {
    if (newName.trim().isEmpty) return;

    // Ensure the new name ends with ".pdf".
    if (!newName.toLowerCase().endsWith('.pdf')) {
      newName = '${newName.trim()}.pdf';
    }

    final directory = oldFile.parent;
    final newPath = '${directory.path}${Platform.pathSeparator}$newName';

    try {
      final newFile = await oldFile.rename(newPath);
      setState(() {
        final originalIndex = widget.pdfs.indexWhere((pdf) => pdf.path == oldFile.path);
        if (originalIndex != -1) {
          widget.pdfs[originalIndex] = newFile;
        }
        // Update favorite status if needed.
        if (_favoritePdfPaths.contains(oldFile.path)) {
          _favoritePdfPaths.remove(oldFile.path);
          _favoritePdfPaths.add(newFile.path);
          _updateFavorites();
        }
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

  // Show a dialog to rename a PDF.
  Future<void> _showRenameDialog(File file) async {
    final oldName = file.path.split(Platform.pathSeparator).last;
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
      await _renamePdf(file, newName);
    }
  }

  // Update shared preferences to reflect the current PDF list.
  Future<void> _updateSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final pdfPaths = widget.pdfs.map((file) => file.path).toList();
    await prefs.setStringList('pdfs', pdfPaths);
  }

  // Open a file picker to upload a new PDF.
  Future<void> _uploadNewPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      final newFile = File(result.files.single.path!);
      setState(() {
        widget.pdfs.add(newFile);
      });
      await _updateSharedPrefs();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF uploaded successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemCount = _finalPdfs.length;
    final isEmpty = itemCount == 0;
    final allSelected = _selectedPaths.length == itemCount && itemCount > 0;

    // Build AppBar actions based on selection mode and search state.
    List<Widget> actions;
    if (_selectionMode) {
      actions = [
        IconButton(
          icon: Icon(allSelected ? Icons.clear_all : Icons.select_all),
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
      ];
    } else {
      actions = [
        _showSearch
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showSearch = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                tooltip: 'Close Search',
              )
            : IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () {
                  setState(() {
                    _showSearch = true;
                  });
                },
                tooltip: 'Search',
              ),
        // Sorting options.
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort PDFs',
          onSelected: (value) {
            setState(() {
              _sortOption = value;
            });
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'name', child: Text('Name')),
            const PopupMenuItem(value: 'date', child: Text('Date Modified')),
            const PopupMenuItem(value: 'size', child: Text('File Size')),
          ],
        ),
        // Favorites filter toggle.
        IconButton(
          icon: Icon(_showFavoritesOnly ? Icons.favorite : Icons.favorite_border),
          tooltip: _showFavoritesOnly ? 'Show All PDFs' : 'Show Favorites Only',
          onPressed: () {
            setState(() {
              _showFavoritesOnly = !_showFavoritesOnly;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.upload_file_rounded),
          onPressed: _uploadNewPdf,
          tooltip: 'Upload New PDF',
        ),
      ];
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
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
                    'Selected (${_selectedPaths.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  )
                : _showSearch
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search PDFs...',
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(
                          fontSize: 20,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      )
                    : const Text(
                        'Documents',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
            actions: actions,
          ),
          if (isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Lottie.network(
                      'https://assets10.lottiefiles.com/packages/lf20_jcikwtux.json',
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No documents available\nTry uploading a new PDF.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final file = _finalPdfs[index];
                  final isSelected = _selectedPaths.contains(file.path);
                  // Use Dismissible when not in selection mode.
                  return _selectionMode
                      ? _buildPdfCard(file, isSelected)
                      : Dismissible(
                          key: Key(file.path),
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            color: Colors.redAccent,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.redAccent,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete PDF'),
                                content: const Text('Are you sure you want to delete this PDF?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                if (await file.exists()) {
                                  await file.delete();
                                }
                                setState(() {
                                  widget.pdfs.removeWhere((pdf) => pdf.path == file.path);
                                });
                                await _updateSharedPrefs();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('PDF deleted.')),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error deleting PDF: $e')),
                                );
                              }
                            } else {
                              // Rebuild list to show item again.
                              setState(() {});
                            }
                          },
                          child: _buildPdfCard(file, isSelected),
                        );
                },
                childCount: itemCount,
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a card representing a PDF file with metadata and actions.
  Widget _buildPdfCard(File file, bool isSelected) {
    final theme = Theme.of(context);
    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileStat = file.statSync();
    final fileSize = _formatFileSize(fileStat.size);
    final modifiedDate = fileStat.modified;
    final formattedDate = DateFormat('dd-MM-yyyy HH:mm a').format(modifiedDate);

    final baseCardColor = theme.cardColor;
    final selectedColor = theme.colorScheme.primary.withOpacity(0.12);

    return GestureDetector(
      onTap: () => _onPdfTap(file),
      onLongPress: () => _onPdfLongPress(file),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              // Favorite toggle.
              IconButton(
                icon: Icon(
                  _favoritePdfPaths.contains(file.path)
                      ? Icons.star
                      : Icons.star_border,
                  color: _favoritePdfPaths.contains(file.path)
                      ? Colors.amber
                      : null,
                ),
                onPressed: () => _toggleFavorite(file),
                tooltip: _favoritePdfPaths.contains(file.path)
                    ? 'Unmark Favorite'
                    : 'Mark as Favorite',
              ),
              if (isSelected)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.check_circle_rounded),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'rename') {
                    _showRenameDialog(file);
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

  /// Formats the file size into a human-readable string.
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

// In-app PDF viewer screen with a gradient background.
class PdfViewerScreen extends StatelessWidget {
  final String path;
  const PdfViewerScreen({Key? key, required this.path}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Gradient background.
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
                elevation: 0,
              ),
              Expanded(
                child: PDFView(
                  filePath: path,
                  enableSwipe: true,
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