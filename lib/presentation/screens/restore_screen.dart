import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/core/services/drive_service.dart';
import 'package:cointally/presentation/screens/main_navigation_screen.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';

class RestoreScreen extends StatefulWidget {
  final String userEmail;
  const RestoreScreen({super.key, required this.userEmail});

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  bool _isRestoring = false;

  Future<void> _handleRestore() async {
    setState(() => _isRestoring = true);
    
    final success = await DriveService().restoreBackup();
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data restored successfully!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        );
      } else {
        setState(() => _isRestoring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to restore data. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_done_rounded, size: 80, color: Colors.green),
              const SizedBox(height: 32),
              Text(
                'Welcome Back!',
                style: GoogleFonts.manrope(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'We found an existing backup for ${widget.userEmail}. Would you like to restore your data?',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 48),
              if (_isRestoring)
                const CircularProgressIndicator()
              else ...[
                NeonButton(
                  text: 'Restore Data',
                  onPressed: _handleRestore,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                    );
                  },
                  child: Text(
                    'Start Fresh (Skip Restore)',
                    style: GoogleFonts.manrope(color: Colors.grey),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
