import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _smsNotifications = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Notifications Section
          _SectionHeader(title: 'Notifications'),
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Receive updates about offers and points'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
            },
            secondary: const Icon(Icons.notifications),
          ),
          if (_notificationsEnabled) ...[
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('In-app notifications'),
              value: _pushNotifications,
              onChanged: (value) {
                setState(() => _pushNotifications = value);
              },
            ),
            SwitchListTile(
              title: const Text('Email Notifications'),
              subtitle: const Text('Updates via email'),
              value: _emailNotifications,
              onChanged: (value) {
                setState(() => _emailNotifications = value);
              },
            ),
            SwitchListTile(
              title: const Text('SMS Notifications'),
              subtitle: const Text('Updates via text message'),
              value: _smsNotifications,
              onChanged: (value) {
                setState(() => _smsNotifications = value);
              },
            ),
          ],
          const Divider(),

          // Account Section
          _SectionHeader(title: 'Account'),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change Password'),
            subtitle: const Text('Reset your password via email'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final email = FirebaseAuth.instance.currentUser?.email;
              if (email != null) {
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password reset email sent')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.subscriptions),
            title: const Text('Subscription & Billing'),
            subtitle: const Text('Manage your plan in Stripe'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pushNamed('/billing');
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Privacy Policy'),
                  content: const SingleChildScrollView(
                    child: Text(
                      'Urban Points Lebanon Privacy Policy\n\n'
                      'We collect and process your personal data in accordance with Lebanese data protection laws.\n\n'
                      'Data we collect:\n'
                      '• Name, email, phone number\n'
                      '• Points and transaction history\n'
                      '• Device information\n'
                      '• Location data (with permission)\n\n'
                      'Your rights:\n'
                      '• Access your data\n'
                      '• Request data deletion\n'
                      '• Opt-out of communications\n\n'
                      'Contact: support@urbanpoints.lb',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.gavel),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Terms of Service'),
                  content: const SingleChildScrollView(
                    child: Text(
                      'Urban Points Lebanon Terms of Service\n\n'
                      '1. Acceptance of Terms\n'
                      'By using Urban Points, you agree to these terms.\n\n'
                      '2. Points System\n'
                      '• Points have no cash value\n'
                      '• Points expire after 12 months of inactivity\n'
                      '• Points cannot be transferred\n\n'
                      '3. User Conduct\n'
                      '• No fraudulent activity\n'
                      '• One account per person\n'
                      '• Accurate information required\n\n'
                      '4. Merchant Offers\n'
                      '• Subject to availability\n'
                      '• Merchants may modify or cancel offers\n'
                      '• Redemption limits apply\n\n'
                      '5. Liability\n'
                      'We are not responsible for merchant services.\n\n'
                      'Contact: support@urbanpoints.lb',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export My Data'),
            subtitle: const Text('Download your data in JSON format'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _exportData(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever),
            title: const Text('Delete Account'),
            subtitle: const Text('Permanently delete your account and data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _deleteAccount(context),
          ),
          const Divider(),

          // App Section
          _SectionHeader(title: 'App'),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            subtitle: const Text('Version 1.0.0'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Urban Points Lebanon',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2025 Urban Points Lebanon',
                children: [
                  const SizedBox(height: 16),
                  const Text('A loyalty and rewards platform connecting '
                      'consumers, merchants, and businesses across Lebanon.'),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Email: support@urbanpoints.lb'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Your Data'),
        content: const Text(
          'This will download all your Urban Points data including:\n\n'
          '• Your profile\n'
          '• Points and transaction history\n'
          '• Redeemed offers\n\n'
          'Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDataExport(context);
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDataExport(BuildContext context) async {
    try {
      _showLoadingDialog(context, 'Exporting your data...');

      final callable = FirebaseFunctions.instance.httpsCallable('exportUserData');
      final result = await callable.call();

      if (mounted) {
        // ignore: use_build_context_synchronously
        Navigator.pop(context); // Close loading dialog
      }

      if (result.data['success'] == true) {
        if (mounted) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Data exported: ${result.data['message']}'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        Navigator.pop(context); // Close loading dialog
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        Navigator.pop(context); // Close loading dialog
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account?\n\n'
          'This will permanently delete:\n'
          '• Your profile\n'
          '• All points\n'
          '• Transaction history\n\n'
          'This action cannot be undone.\n\n'
          'You will be signed out immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _performAccountDeletion(context);
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  Future<void> _performAccountDeletion(BuildContext context) async {
    try {
      _showLoadingDialog(context, 'Deleting your account...');

      final callable = FirebaseFunctions.instance.httpsCallable('deleteUserData');
      final result = await callable.call();

      if (mounted) {
        // ignore: use_build_context_synchronously
        Navigator.pop(context); // Close loading dialog
      }

      if (result.data['success'] == true) {
        // Sign out the user
        await FirebaseAuth.instance.signOut();

        if (mounted) {
          // ignore: use_build_context_synchronously
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deleted successfully'),
            ),
          );
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        Navigator.pop(context); // Close loading dialog
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deletion failed: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        Navigator.pop(context); // Close loading dialog
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
