import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
// mailer dependencies
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart'; // for kAppVersion

class SettingsScreen extends StatefulWidget {
  // Removed appName and onAppNameChanged since we're no longer changing the app name
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

  /// Show bottom sheet, then send email directly via SMTP
  void _openFeedbackFormDirectSMTP() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final TextEditingController _feedbackController = TextEditingController();

        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              children: [
                Text(
                  'Share Your Thoughts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _feedbackController,
                  autofocus: true,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Ideas, suggestions, or issues...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final feedback = _feedbackController.text.trim();
                        if (feedback.isEmpty) {
                          Navigator.pop(context);
                          return;
                        }

                        final success = await _sendEmail(feedback);

                        _feedbackController.clear();
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
                      child: const Text('SUBMIT'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Actually sends the email using mailer. 
  /// WARNING: Storing credentials in the client is insecure.
  Future<bool> _sendEmail(String feedback) async {
    const username = '9a4f765dbe185a';
    const password = '929d826701bafa';
    const destinationEmail = 'krishnak.pilato@gmail.com'; // Where you want feedback

    final smtpServer = gmail(username, password);

    final message = Message()
      ..from = Address(username, 'HeritaScan App')
      ..recipients.add(destinationEmail)
      ..subject = 'Feedback from HeritaScan'
      ..text = feedback;

    try {
      final sendReport = await send(message, smtpServer);
      debugPrint('Message sent: $sendReport');
      return true;
    } on MailerException catch (e) {
      debugPrint('Message not sent. ${e.message}');
      for (var p in e.problems) {
        debugPrint('Problem: ${p.code}: ${p.msg}');
      }
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
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // --- Appearance Section ---
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

          // --- Directories Section ---
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

          // --- Feedback Section ---
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
            onTap: _openFeedbackFormDirectSMTP, // <--- Use direct SMTP
          ),
          const Divider(height: 32),

          // --- About Section ---
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
            leading: const Icon(Icons.person_rounded),
            title: const Text('Khova Krishna Pilato'),
            subtitle: const Text('Thank you for using my app!'),
          ),
        ],
      ),
    );
  }
}