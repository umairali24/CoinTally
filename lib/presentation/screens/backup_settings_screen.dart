import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cointally/core/services/cloud_auth_service.dart';
import 'package:cointally/core/services/drive_service.dart';
import 'package:cointally/presentation/notifiers/locale_notifier.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';

class BackupSettingsScreen extends ConsumerStatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  ConsumerState<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends ConsumerState<BackupSettingsScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _userEmail;
  DateTime? _lastBackupTime;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    
    final authService = CloudAuthService();
    final isSignedIn = await authService.isSignedIn();
    
    if (isSignedIn) {
      final user = await authService.signInSilently();
      _userEmail = user?.email;
      
      if (_userEmail != null) {
         final backup = await DriveService().findBackup();
         if (backup != null && backup.modifiedTime != null) {
           _lastBackupTime = backup.modifiedTime;
         } else {
           _lastBackupTime = null;
         }
      }
    } else {
      _userEmail = null;
      _lastBackupTime = null;
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignIn() async {
    setState(() => _isProcessing = true);
    final user = await CloudAuthService().signIn();
    if (user != null) {
      await _checkStatus();
    }
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleSignOut() async {
    setState(() => _isProcessing = true);
    await CloudAuthService().signOut();
    await _checkStatus();
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleBackup() async {
    setState(() => _isProcessing = true);
    final success = await DriveService().uploadBackup();
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup successful!')),
        );
        await _checkStatus(); // Refresh the date
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup failed. Please try again.')),
        );
      }
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text('Restore Data?', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Text(
          'This will overwrite all your current data with the data from your last backup. This action cannot be undone.',
          style: GoogleFonts.manrope(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.manrope(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Restore', style: GoogleFonts.manrope(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      final success = await DriveService().restoreBackup();
      
      if (mounted) {
        setState(() => _isProcessing = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data restored successfully! Please restart the app.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to restore data. Please check your connection and try again.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeNotifier = ref.read(localeProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(localeNotifier.translate('backup_restore'), style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.cloud_sync_rounded, size: 80, color: Colors.blue),
                  const SizedBox(height: 32),
                  
                  if (_userEmail == null) ...[
                    Text(
                      'Sign in to Google to backup your data to Google Drive and keep it safe.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_isProcessing)
                       const Center(child: CircularProgressIndicator())
                    else
                       NeonButton(
                        text: 'Sign in with Google',
                        onPressed: _handleSignIn,
                      ),
                  ] else ...[
                    // Account info card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.account_circle, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Google Account',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                                      ),
                                    ),
                                    Text(
                                      _userEmail!,
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _isProcessing ? null : _handleSignOut,
                                child: Text('Sign Out', style: GoogleFonts.manrope(fontSize: 12)),
                              )
                            ],
                          ),
                          const Divider(height: 32),
                          Row(
                            children: [
                              Icon(Icons.update_rounded, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Last Backup',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                                      ),
                                    ),
                                    Text(
                                      _lastBackupTime != null 
                                          ? DateFormat('MMM dd, yyyy - hh:mm a').format(_lastBackupTime!.toLocal())
                                          : 'Never',
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    if (_isProcessing)
                       const Center(child: CircularProgressIndicator())
                    else ...[
                      NeonButton(
                        text: 'Backup Now',
                        onPressed: _handleBackup,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _lastBackupTime == null ? null : _handleRestore,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Theme.of(context).colorScheme.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Restore Data',
                            style: GoogleFonts.manrope(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ]
                  ],
                ],
              ),
            ),
    );
  }
}
