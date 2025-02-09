import 'dart:convert';
import 'dart:io';

import 'package:emailjs/emailjs.dart' as EmailJS;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkTheme = false;

  void _toggleTheme(bool isDark) {
    setState(() {
      _isDarkTheme = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Settings App',
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: _isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      home: SettingsScreen(
        isDarkTheme: _isDarkTheme,
        onThemeChanged: _toggleTheme,
      ),
    );
  }
}

/// A helper widget to display section headers.
class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({Key? key, required this.title}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The SettingsScreen allows users to configure app appearance, directories, feedback, and more.
class SettingsScreen extends StatefulWidget {
  final bool isDarkTheme;
  final ValueChanged<bool> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.isDarkTheme,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _photosDirectory;
  String? _pdfsDirectory;

  // App version (update accordingly)
  String get kAppVersion => "0.1.5";

  @override
  void initState() {
    super.initState();
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
    final String? selectedDirectory =
        await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (type == 'photos') {
      setState(() => _photosDirectory = selectedDirectory);
      await prefs.setString('photosDirectory', selectedDirectory);
    } else if (type == 'pdfs') {
      setState(() => _pdfsDirectory = selectedDirectory);
      await prefs.setString('pdfsDirectory', selectedDirectory);
    }
  }

  Future<void> _resetDirectory(String type) async {
    final prefs = await SharedPreferences.getInstance();
    if (type == 'photos') {
      setState(() {
        _photosDirectory = null;
      });
      await prefs.remove('photosDirectory');
    } else if (type == 'pdfs') {
      setState(() {
        _pdfsDirectory = null;
      });
      await prefs.remove('pdfsDirectory');
    }
  }

  /// Opens a feedback form as a bottom sheet.
  void _openFeedbackForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        // Local state for the bottom sheet.
        String? feedbackType;
        String? attachmentFileName;
        String? attachmentBase64;
        bool isSending = false;
        final TextEditingController feedbackController =
            TextEditingController();

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> _pickAttachment() async {
              final result = await FilePicker.platform.pickFiles();
              if (result != null && result.files.single.path != null) {
                final filePath = result.files.single.path!;
                final fileBytes = await File(filePath).readAsBytes();
                setModalState(() {
                  attachmentFileName = result.files.single.name;
                  attachmentBase64 = base64Encode(fileBytes);
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Share Your Thoughts',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Type of feedback',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'Bug Report', child: Text('Bug Report')),
                      DropdownMenuItem(
                          value: 'Suggestion', child: Text('Suggestion')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      setModalState(() {
                        feedbackType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: feedbackController,
                    autofocus: true,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Your feedback',
                      hintText: 'Ideas, suggestions, or issues...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickAttachment,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Attach File'),
                      ),
                      const SizedBox(width: 8),
                      if (attachmentFileName != null)
                        Expanded(
                          child: Text(
                            attachmentFileName!,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (attachmentFileName != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setModalState(() {
                              attachmentFileName = null;
                              attachmentBase64 = null;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            isSending ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: isSending
                            ? null
                            : () async {
                                final feedback = feedbackController.text.trim();
                                if (feedback.isEmpty || feedbackType == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Please select a type and enter your feedback.'),
                                    ),
                                  );
                                  return;
                                }
                                setModalState(() {
                                  isSending = true;
                                });
                                final success = await _sendFeedbackEmail(
                                  feedbackType!,
                                  feedback,
                                  attachmentBase64: attachmentBase64,
                                  attachmentFileName: attachmentFileName,
                                );
                                setModalState(() {
                                  isSending = false;
                                });
                                feedbackController.clear();
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success
                                        ? 'Thanks for your feedback!'
                                        : 'Could not send feedback.'),
                                  ),
                                );
                              },
                        child: isSending
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text('Send'),
                                  SizedBox(width: 4),
                                  Icon(Icons.send_rounded),
                                ],
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Sends feedback via EmailJS. Optionally attaches a file if provided.
  Future<bool> _sendFeedbackEmail(
    String type,
    String feedback, {
    String? attachmentBase64,
    String? attachmentFileName,
  }) async {
    try {
      final Map<String, dynamic> templateParams = {
        'feedback_type': type,
        'feedback_message': feedback,
        'to_email': 'krishnak.pilato@gmail.com',
      };

      if (attachmentBase64 != null && attachmentFileName != null) {
        templateParams['feedback_attachment'] = attachmentBase64;
        templateParams['feedback_attachment_name'] = attachmentFileName;
      }

      await EmailJS.send(
        'service_xg0zung',
        'template_6yjljvi',
        {
          'user_id': 'Snh_1YI8Oz07iuS5R',
          'template_params': templateParams,
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error sending via EmailJS: $e');
      return false;
    }
  }

  /// New Feature: Resets all settings stored in SharedPreferences.
  Future<void> _resetAllSettings() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset All Settings'),
          content: const Text(
              'Are you sure you want to reset all settings? This will clear directories, theme settings, and any other stored preferences.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      setState(() {
        _photosDirectory = null;
        _pdfsDirectory = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All settings have been reset.')),
      );
    }
  }

  /// New Feature: Opens a URL so the user can rate the app.
  Future<void> _rateApp() async {
    const url =
        'https://play.google.com/store/apps/details?id=com.example.heritascan';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the rating page.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDarkTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          const SectionHeader(title: 'Appearance'),
          SwitchListTile(
            title: const Text('Dark Theme'),
            secondary: const Icon(Icons.dark_mode_rounded),
            value: isDark,
            onChanged: (bool value) {
              widget.onThemeChanged(value);
              setState(() {});
            },
          ),
          const Divider(height: 32),
          // Directories Section
          const SectionHeader(title: 'Directories'),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Photos Directory'),
            subtitle: Text(
              _photosDirectory ?? 'Not set',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: () => _pickDirectory('photos'),
                  child: const Text('Change'),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _resetDirectory('photos'),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded),
            title: const Text('PDFs Directory'),
            subtitle: Text(
              _pdfsDirectory ?? 'Not set',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: () => _pickDirectory('pdfs'),
                  child: const Text('Change'),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _resetDirectory('pdfs'),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          // Feedback Section
          const SectionHeader(title: 'Feedback'),
          ListTile(
            leading: const Icon(Icons.feedback_rounded),
            title: const Text('Send Feedback / Ideas'),
            subtitle: Text(
              'I’d love to hear from you!',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            onTap: _openFeedbackForm,
          ),
          const Divider(height: 32),
          // About Section
          const SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.info_rounded),
            title: const Text('App Version'),
            subtitle: Text(
              kAppVersion,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: const Text('Open Source Licenses'),
            subtitle: const Text("View libraries used in this app."),
            onTap: () {
              showLicensePage(context: context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.source_rounded),
            title: const Text('Source Code'),
            onTap: () async {
              const url = 'https://github.com/krishnapilato/heritascan';
              if (await canLaunch(url)) {
                // ignore: deprecated_member_use
                await launch(url);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open URL.')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_rounded),
            title: const Text('Khova Krishna Pilato'),
            subtitle: const Text('Full Stack Developer'),
          ),
          // New "More" Section
          const SectionHeader(title: 'More'),
          ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: const Text('Reset All Settings'),
            subtitle: const Text('Clear all saved preferences.'),
            onTap: _resetAllSettings,
          ),
          ListTile(
            leading: const Icon(Icons.star_rate_rounded),
            title: const Text('Rate this App'),
            subtitle: const Text('Let others know what you think.'),
            onTap: _rateApp,
          ),
        ],
      ),
    );
  }
}