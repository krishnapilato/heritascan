import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart'; // If you need kAppVersion, or you can re-declare it here.

class SettingsScreen extends StatefulWidget {
  final String appName;
  final ValueChanged<String> onAppNameChanged;
  final bool isDarkTheme;
  final ValueChanged<bool> onThemeChanged;

  const SettingsScreen({
    Key? key,
    required this.appName,
    required this.onAppNameChanged,
    required this.isDarkTheme,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _appNameController;
  String? _photosDirectory;
  String? _pdfsDirectory;

  @override
  void initState() {
    super.initState();
    _appNameController = TextEditingController(text: widget.appName);
    _loadDirectories();
  }

  Future<void> _loadDirectories() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _photosDirectory = prefs.getString('photosDirectory');
      _pdfsDirectory = prefs.getString('pdfsDirectory');
    });
  }

  Future<void> _pickDirectory(String type) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (type == 'photos') {
      setState(() {
        _photosDirectory = selectedDirectory;
      });
      await prefs.setString('photosDirectory', selectedDirectory);
    } else if (type == 'pdfs') {
      setState(() {
        _pdfsDirectory = selectedDirectory;
      });
      await prefs.setString('pdfsDirectory', selectedDirectory);
    }
  }

  void _updateAppName() {
    widget.onAppNameChanged(_appNameController.text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F2027), const Color(0xFF203A43)]
                : [const Color(0xFFa8c0ff), const Color(0xFFfbc2eb)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Settings'),
                backgroundColor: Colors.transparent,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // App Name
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: const Text('App Name'),
                        subtitle: TextField(
                          controller: _appNameController,
                          decoration: const InputDecoration(
                            hintText: 'Enter a custom name',
                          ),
                          onSubmitted: (_) => _updateAppName(),
                          onEditingComplete: _updateAppName,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dark Theme Toggle
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        title: const Text('Dark Theme'),
                        value: isDark,
                        onChanged: (bool value) {
                          widget.onThemeChanged(value);
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Photos Directory
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: const Text('Photos Directory'),
                        subtitle: Text(_photosDirectory ?? 'Not set'),
                        trailing: ElevatedButton(
                          onPressed: () => _pickDirectory('photos'),
                          child: const Text('Change'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // PDFs Directory
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: const Text('PDFs Directory'),
                        subtitle: Text(_pdfsDirectory ?? 'Not set'),
                        trailing: ElevatedButton(
                          onPressed: () => _pickDirectory('pdfs'),
                          child: const Text('Change'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // App Version (fetched from main.dart if needed)
                    Center(
                      child: Text(
                        'Version: $kAppVersion',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
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