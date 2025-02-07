// ignore_for_file: deprecated_member_use

import 'dart:convert'; // For JSON encode/decode
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
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
  // ---------------- SELECTION MODE VARIABLES ----------------
  Set<String> _selectedPaths = {};
  bool _selectionMode = false;

  // ---------------- SEARCH & FILTER VARIABLES ----------------
  bool _showSearch = false;
  bool _showFavoritesOnly = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Sorting option: 'name', 'date', 'size'
  String _sortOption = 'name';

  // Date filter variables.
  DateTime? _startDate;
  DateTime? _endDate;

  // ---------------- FAVORITES, PINNED & NOTES ----------------
  Set<String> _favoritePdfPaths = {};
  Set<String> _pinnedPdfPaths = {};
  Map<String, String> _pdfNotes = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadPinned();
    _loadNotes();
  }

  // ---------------- FAVORITES ----------------
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoritePdfPaths = prefs.getStringList('favoritePdfs')?.toSet() ?? {};
    });
  }

  Future<void> _updateFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoritePdfs', _favoritePdfPaths.toList());
  }

  // ---------------- PINNED PDFs ----------------
  Future<void> _loadPinned() async {
    final prefs = await SharedPreferences.getInstance();
    final pinnedList = prefs.getStringList('pinnedPdfs') ?? [];
    setState(() {
      _pinnedPdfPaths = pinnedList.toSet();
    });
  }

  Future<void> _updatePinned() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinnedPdfs', _pinnedPdfPaths.toList());
  }

  void _togglePin(File file) {
    setState(() {
      if (_pinnedPdfPaths.contains(file.path)) {
        _pinnedPdfPaths.remove(file.path);
      } else {
        _pinnedPdfPaths.add(file.path);
      }
    });
    _updatePinned();
  }

  // ---------------- NOTES ----------------
  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getString('pdfNotes') ?? '{}';
    final decoded = jsonDecode(notesJson) as Map<String, dynamic>;
    _pdfNotes = decoded.map((k, v) => MapEntry(k, v as String));
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = jsonEncode(_pdfNotes);
    await prefs.setString('pdfNotes', notesJson);
  }

  Future<void> _showNoteDialog(File file) async {
    final currentNote = _pdfNotes[file.path] ?? '';
    final controller = TextEditingController(text: currentNote);
    final newNote = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add/Edit Note'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Write your note here...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newNote != null) {
      setState(() {
        _pdfNotes[file.path] = newNote.trim();
      });
      await _saveNotes();
    }
  }

  // ---------------- FILTERS & SORTS ----------------
  List<File> get _filteredPdfs {
    List<File> list = widget.pdfs;
    if (_searchQuery.isNotEmpty) {
      list = list.where((file) {
        final fileName =
            file.path.split(Platform.pathSeparator).last.toLowerCase();
        return fileName.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    if (_startDate != null && _endDate != null) {
      list = list.where((file) {
        DateTime mod = file.statSync().modified;
        // Include files modified on _endDate as well.
        return mod.isAfter(_startDate!) &&
            mod.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }
    return list;
  }

  List<File> get _finalPdfs {
    List<File> list = _filteredPdfs;
    if (_showFavoritesOnly) {
      list =
          list.where((file) => _favoritePdfPaths.contains(file.path)).toList();
    }
    final pinned = list.where((f) => _pinnedPdfPaths.contains(f.path)).toList();
    final unpinned =
        list.where((f) => !_pinnedPdfPaths.contains(f.path)).toList();
    pinned.sort((a, b) => _compareFiles(a, b));
    unpinned.sort((a, b) => _compareFiles(a, b));
    return [...pinned, ...unpinned];
  }

  int _compareFiles(File a, File b) {
    switch (_sortOption) {
      case 'name':
        final aName = a.path.split(Platform.pathSeparator).last.toLowerCase();
        final bName = b.path.split(Platform.pathSeparator).last.toLowerCase();
        return aName.compareTo(bName);
      case 'date':
        return b.statSync().modified.compareTo(a.statSync().modified);
      case 'size':
        return b.statSync().size.compareTo(a.statSync().size);
      default:
        return 0;
    }
  }

  // ---------------- SELECTION & ACTIONS ----------------
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

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Container(
        color: Colors.black54,
        child: Center(
          child: Lottie.network(
            'https://assets10.lottiefiles.com/packages/lf20_usmfx6bp.json',
            width: 650,
            height: 450,
            fit: BoxFit.fill,
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

  void _onPdfTap(File file) {
    if (_selectionMode) {
      _toggleSelection(file.path);
    } else {
      _openPdf(file);
    }
  }

  void _onPdfLongPress(File file) {
    _toggleSelection(file.path);
  }

  Future<void> _confirmDeleteSelectedPdfs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete PDFs'),
        content:
            const Text('Are you sure you want to delete the selected PDFs?'),
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

  void _cancelSelection() {
    setState(() {
      _selectedPaths.clear();
      _selectionMode = false;
    });
  }

  Future<void> _renamePdf(File oldFile, String newName) async {
    if (newName.trim().isEmpty) return;
    if (!newName.toLowerCase().endsWith('.pdf')) {
      newName = '${newName.trim()}.pdf';
    }
    final directory = oldFile.parent;
    final newPath = '${directory.path}${Platform.pathSeparator}$newName';
    try {
      final newFile = await oldFile.rename(newPath);
      setState(() {
        final originalIndex =
            widget.pdfs.indexWhere((pdf) => pdf.path == oldFile.path);
        if (originalIndex != -1) {
          widget.pdfs[originalIndex] = newFile;
        }
        if (_favoritePdfPaths.contains(oldFile.path)) {
          _favoritePdfPaths.remove(oldFile.path);
          _favoritePdfPaths.add(newFile.path);
          _updateFavorites();
        }
        if (_pinnedPdfPaths.contains(oldFile.path)) {
          _pinnedPdfPaths.remove(oldFile.path);
          _pinnedPdfPaths.add(newFile.path);
          _updatePinned();
        }
        if (_pdfNotes.containsKey(oldFile.path)) {
          final oldNote = _pdfNotes.remove(oldFile.path)!;
          _pdfNotes[newFile.path] = oldNote;
          _saveNotes();
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

  Future<void> _showRenameDialog(File file) async {
    final oldName = file.path.split(Platform.pathSeparator).last;
    final controller =
        TextEditingController(text: oldName.replaceAll('.pdf', ''));
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

  void _showFileDetails(File file) {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileStat = file.statSync();
    final fileSize = _formatFileSize(fileStat.size);
    final modifiedDate =
        DateFormat('dd-MM-yyyy HH:mm a').format(fileStat.modified);
    final noteText = _pdfNotes[file.path] ?? '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final Color containerColor =
            isDark ? theme.scaffoldBackgroundColor : Colors.white;
        final Color iconColor =
            isDark ? theme.iconTheme.color! : Colors.black54;
        final Color textColor = isDark ? Colors.white : Colors.black;
        return Container(
          color: Colors.transparent,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag indicator and close icon.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.cancel, color: iconColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: Icon(Icons.description, color: iconColor),
                    title: Text(
                      'File Name',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: textColor),
                    ),
                    subtitle:
                        Text(fileName, style: TextStyle(color: textColor)),
                  ),
                  ListTile(
                    leading: Icon(Icons.storage, color: iconColor),
                    title: Text(
                      'File Size',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: textColor),
                    ),
                    subtitle:
                        Text(fileSize, style: TextStyle(color: textColor)),
                  ),
                  ListTile(
                    leading: Icon(Icons.access_time, color: iconColor),
                    title: Text(
                      'Modified',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: textColor),
                    ),
                    subtitle:
                        Text(modifiedDate, style: TextStyle(color: textColor)),
                  ),
                  ListTile(
                    leading: Icon(Icons.link, color: iconColor),
                    title: Text(
                      'Full Path',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: textColor),
                    ),
                    subtitle: Text(
                      file.path,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor),
                    ),
                    trailing: GestureDetector(
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: file.path),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('File path copied!')),
                        );
                      },
                      child: Icon(Icons.copy, color: iconColor),
                    ),
                  ),
                  if (noteText.isNotEmpty) ...[
                    const Divider(),
                    ListTile(
                      leading: Icon(Icons.note, color: iconColor),
                      title: Text(
                        'Note',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: textColor),
                      ),
                      subtitle:
                          Text(noteText, style: TextStyle(color: textColor)),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final pdfPaths = widget.pdfs.map((file) => file.path).toList();
    await prefs.setStringList('pdfs', pdfPaths);
  }

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

  Future<void> _filterByDate() async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(2000);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Date filter cleared.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemCount = _finalPdfs.length;
    final isEmpty = itemCount == 0;
    final allSelected = _selectedPaths.length == itemCount && itemCount > 0;

    // ---------------- Build AppBar Actions ----------------
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
      // When not in selection mode, show a search button.
      actions = _showSearch
          ? [] // Hide all actions when search mode is active.
          : [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search',
                onPressed: () {
                  setState(() {
                    _showSearch = true;
                  });
                },
              ),
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
                  const PopupMenuItem(
                      value: 'date', child: Text('Date Modified')),
                  const PopupMenuItem(value: 'size', child: Text('File Size')),
                ],
              ),
              IconButton(
                icon: Icon(
                  Icons.date_range,
                  color: _startDate != null ? Colors.red : null,
                ),
                onPressed: () async {
                  if (_startDate != null && _endDate != null) {
                    _clearDateFilter();
                  } else {
                    await _filterByDate();
                  }
                },
                tooltip:
                    _startDate != null ? 'Clear Date Filter' : 'Filter by Date',
              ),
              IconButton(
                icon: Icon(_showFavoritesOnly
                    ? Icons.favorite
                    : Icons.favorite_border),
                tooltip: _showFavoritesOnly
                    ? 'Show All PDFs'
                    : 'Show Favorites Only',
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
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadFavorites();
          await _loadPinned();
          await _loadNotes();
          setState(() {});
        },
        child: CustomScrollView(
          slivers: [
            // ---------------- AppBar ----------------
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
              title: _showSearch
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search PDFs...',
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.cancel),
                          onPressed: () {
                            setState(() {
                              _showSearch = false;
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        ),
                      ),
                      style: const TextStyle(fontSize: 20),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    )
                  : _selectionMode
                      ? Text(
                          'Selected (${_selectedPaths.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        )
                      : const Text(
                          'Documents',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800),
                        ),
              actions: actions,
            ),
            // ---------------- Content ----------------
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
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 300),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: Slidable(
                            key: Key(file.path),
                            startActionPane: ActionPane(
                              motion: const DrawerMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (context) =>
                                      _showRenameDialog(file),
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  icon: Icons.edit,
                                  label: 'Rename',
                                ),
                                SlidableAction(
                                  onPressed: (context) =>
                                      _showFileDetails(file),
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                  icon: Icons.info,
                                  label: 'Details',
                                ),
                              ],
                            ),
                            endActionPane: ActionPane(
                              motion: const DrawerMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (context) async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete PDF'),
                                        content: const Text(
                                            'Are you sure you want to delete this PDF?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Delete',
                                                style: TextStyle(
                                                    color: Colors.red)),
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
                                          widget.pdfs.removeWhere(
                                              (pdf) => pdf.path == file.path);
                                        });
                                        await _updateSharedPrefs();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text('PDF deleted.')),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'Error deleting PDF: $e')),
                                        );
                                      }
                                    }
                                  },
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete,
                                  label: 'Delete',
                                ),
                              ],
                            ),
                            child: GestureDetector(
                              onTap: () => _onPdfTap(file),
                              onLongPress: () => _onPdfLongPress(file),
                              child: _buildPdfCard(file, isSelected),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: itemCount,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Improved PDF Card with enhanced spacing, larger icon, and refined layout.
  Widget _buildPdfCard(File file, bool isSelected) {
    final theme = Theme.of(context);
    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileStat = file.statSync();
    final fileSize = _formatFileSize(fileStat.size);
    final modifiedDate =
        DateFormat('dd-MM-yyyy HH:mm a').format(fileStat.modified);

    final baseCardColor = theme.cardColor;
    final selectedColor = theme.colorScheme.primary.withOpacity(0.12);
    final pinned = _pinnedPdfPaths.contains(file.path);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? selectedColor : baseCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (theme.brightness == Brightness.light)
            BoxShadow(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.2)
                  : Colors.black12,
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // PDF icon
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.transparent,
              child: Icon(Icons.picture_as_pdf, size: 32, color: Colors.red),
            ),
            const SizedBox(width: 16),
            // File details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$fileSize • $modifiedDate',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            // Trailing icons for favorite and pin
            Column(
              children: [
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
                IconButton(
                  icon: Icon(
                    pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: pinned ? theme.colorScheme.primary : null,
                  ),
                  onPressed: () => _togglePin(file),
                  tooltip: pinned ? 'Unpin PDF' : 'Pin PDF',
                ),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'rename') {
                  _showRenameDialog(file);
                } else if (value == 'details') {
                  _showFileDetails(file);
                } else if (value == 'note') {
                  _showNoteDialog(file);
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'rename',
                  child: Text('Rename'),
                ),
                const PopupMenuItem<String>(
                  value: 'details',
                  child: Text('Details'),
                ),
                const PopupMenuItem<String>(
                  value: 'note',
                  child: Text('Add/Edit Note'),
                ),
              ],
            ),
          ],
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

// ---------------- In-App PDF Viewer ----------------
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