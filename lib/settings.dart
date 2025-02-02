import 'package:emailjs/emailjs.dart' as EmailJS; // <-- EmailJS import
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkTheme;
  final ValueChanged<bool> onThemeChanged;

  const SettingsScreen({
    Key? key,
    required this.isDarkTheme,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _photosDirectory;
  String? _pdfsDirectory;

  // Use the same version as in your main file (or update accordingly)
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
    final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
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

  /// Opens a bottom sheet that uses Material 3 styling (with extra padding,
  /// a dropdown for selecting feedback type, and a large text field)
  void _openFeedbackForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        String? feedbackType;
        final TextEditingController feedbackController = TextEditingController();

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
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // "Select Type" Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Type of feedback',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Bug Report', child: Text('Bug Report')),
                  DropdownMenuItem(value: 'Suggestion', child: Text('Suggestion')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  feedbackType = value;
                },
              ),
              const SizedBox(height: 16),
              // Multi-line text field for feedback
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
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () async {
                      final feedback = feedbackController.text.trim();
                      if (feedback.isEmpty || feedbackType == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select type & enter feedback.')),
                        );
                        return;
                      }

                      final success = await _sendFeedbackEmail(feedbackType!, feedback);
                      feedbackController.clear();
                      Navigator.pop(context);

                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Thanks for your feedback!')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not send feedback.')),
                        );
                      }
                    },
                    child: Row(
                      children: const [
                        Text('Send'),
                        SizedBox(width: 4),
                        Icon(Icons.send),
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
  }

  /// Sends the email with EmailJS. Be sure to configure your EmailJS service properly.
  /// Replace the service ID, template ID, and public key with your actual values.
  Future<bool> _sendFeedbackEmail(String type, String feedback) async {
    try {
      await EmailJS.send(
        'service_xg0zung',
        'template_6yjljvi',
        {
          'user_id': 'Snh_1YI8Oz07iuS5R',
          'template_params': {
            'feedback_type': type,
            'feedback_message': feedback,
            'to_email': 'krishnak.pilato@gmail.com',
          },
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error sending via EmailJS: $e');
      return false;
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
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        )
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          Text(
            'Appearance',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
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
          Text(
            'Directories',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Photos Directory'),
            subtitle: Text(
              _photosDirectory ?? 'Not set',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            trailing: FilledButton(
              onPressed: () => _pickDirectory('photos'),
              child: const Text('Change'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded),
            title: const Text('PDFs Directory'),
            subtitle: Text(
              _pdfsDirectory ?? 'Not set',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            trailing: FilledButton(
              onPressed: () => _pickDirectory('pdfs'),
              child: const Text('Change'),
            ),
          ),
          const Divider(height: 32),
          // Feedback Section
          Text(
            'Feedback',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
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
          Text(
            'About',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            subtitle: Text(
              kAppVersion,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Open Source Licenses'),
            subtitle: const Text("View libraries used in this app."),
            onTap: () {
              showLicensePage(context: context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_rounded),
            title: const Text('Khova Krishna Pilato'),
            subtitle: const Text('Full Stack Developer'),
          ),
        ],
      ),
    );
  }
}