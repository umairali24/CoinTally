import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/core/services/cloud_auth_service.dart';
import 'package:cointally/core/services/drive_service.dart';
import 'package:cointally/presentation/screens/main_navigation_screen.dart';
import 'package:cointally/presentation/screens/restore_screen.dart';
import 'package:cointally/presentation/widgets/sleek_components.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    // Only perform silent sign in if we are actually showing the welcome screen
    // and a session existed before (e.g. after log out or fresh reinstall with data)
    final authService = CloudAuthService();
    if (await authService.isSignedIn()) {
      setState(() => _isLoading = true);
      final user = await authService.signInSilently();
      if (user != null) {
        _navigateForward(user.email);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markOnboardingComplete() async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.setBool('onboarding_complete', true);
  }

  void _navigateForward(String email) async {
    await _markOnboardingComplete();
    // Smart Restore Check
    final backup = await DriveService().findBackup();
    
    if (mounted) {
      if (backup != null) {
        // Returning User
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RestoreScreen(userEmail: email),
          ),
        );
      } else {
        // New User
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... preserved UI logic ...
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // App Logo placeholder
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 50,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Cointally',
                style: GoogleFonts.manrope(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).textTheme.displayLarge?.color,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Smart. Private. Halal.',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Take control of your finances with automated tracking and Shariah-compliant tools.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    height: 1.5,
                  ),
                ),
              ),
              const Spacer(),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                NeonButton(
                  text: 'Sign in with Google',
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    final user = await CloudAuthService().signIn();
                    if (user != null) {
                      _navigateForward(user.email);
                    } else {
                      setState(() => _isLoading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sign-in failed. Please try again.')),
                        );
                      }
                    }
                  },
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                   await _markOnboardingComplete();
                   if (mounted) {
                     Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                    );
                   }
                },
                child: Text(
                  'Continue without account',
                  style: GoogleFonts.manrope(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
