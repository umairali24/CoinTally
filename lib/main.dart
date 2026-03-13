import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cointally/presentation/notifiers/locale_notifier.dart';
import 'package:cointally/core/database/database_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cointally/data/local/db_helper.dart';
import 'package:cointally/presentation/notifiers/theme_notifier.dart';
import 'package:cointally/presentation/screens/welcome_screen.dart';
import 'package:cointally/core/services/notification_service.dart';
import 'package:cointally/presentation/screens/add_person_screen.dart';
import 'package:cointally/presentation/screens/person_detail_screen.dart';
import 'package:cointally/domain/entities/person_entity.dart';
import 'package:cointally/core/services/backup_worker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cointally/core/services/cloud_auth_service.dart';
import 'package:cointally/presentation/screens/main_navigation_screen.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:cointally/presentation/screens/lock_screen.dart';
import 'package:cointally/presentation/notifiers/security_notifier.dart';
import 'package:cointally/core/services/telemetry_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("!!! main() started !!!");
  
  await Firebase.initializeApp();
  
  // Debug Firebase instance for DebugView troubleshooting
  await TelemetryService().debugInstanceId();

  await configureDatabase();
  
  // Initialize notifications
  await NotificationService().init();
  await NotificationService().initListener();
  
  // Initialize the DatabaseHelper instance so the DB is ready
  await DatabaseHelper.instance.database;

  // Initialize and schedule background backups
  await BackupWorkerManager.initialize();
  await BackupWorkerManager.scheduleDailyBackup();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final langCode = ref.watch(localeProvider);
    const lightPrimaryColor = Color(0xFF109D10); // Solid green for readability
    const darkPrimaryColor = Color(0xFF13EC13); // Neon green for dark mode
    
    return MaterialApp(
      title: 'Cointally',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      locale: Locale(langCode),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ur'),
      ],
      routes: {
        '/add_person': (context) => const AddPersonScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/person_detail') {
          final person = settings.arguments as PersonEntity;
          return MaterialPageRoute(
            builder: (context) => PersonDetailScreen(person: person),
          );
        }
        return null;
      },
      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: lightPrimaryColor,
          brightness: Brightness.light,
          primary: lightPrimaryColor,
          onPrimary: Colors.black,
          surface: Colors.white,
          onSurface: const Color(0xFF1A1A1A),
          background: const Color(0xFFF5F7FA),
          onBackground: const Color(0xFF1A1A1A),
        ),
        textTheme: GoogleFonts.manropeTextTheme(ThemeData.light().textTheme).copyWith(
          displayLarge: GoogleFonts.manrope(color: const Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
          titleLarge: GoogleFonts.manrope(color: const Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
          bodyLarge: GoogleFonts.manrope(color: const Color(0xFF1A1A1A)),
          bodyMedium: GoogleFonts.manrope(color: const Color(0xFF1A1A1A).withOpacity(0.8)),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardTheme: CardThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.dark, // Force dark icons on light background
          iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
          titleTextStyle: GoogleFonts.manrope(
            color: const Color(0xFF1A1A1A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: lightPrimaryColor,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.manrope(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      // Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: darkPrimaryColor,
          brightness: Brightness.dark,
          primary: darkPrimaryColor,
          onPrimary: Colors.black,
          background: const Color(0xFF0A0A0A),
        ),
        textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A), // Deep charcoal
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.light, // Force light icons on dark background
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkPrimaryColor,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.manrope(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> with WidgetsBindingObserver {
  bool? _isLoggedIn;
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(securityProvider.notifier).updateLastActiveTime();
    } else if (state == AppLifecycleState.resumed) {
      final securityState = ref.read(securityProvider);
      if (securityState.isBiometricEnabled) {
        // Lock if inactive for > 1 minute
        final lastActive = securityState.lastActiveTime;
        if (lastActive != null) {
          final difference = DateTime.now().difference(lastActive);
          if (difference.inMinutes >= 1) {
            ref.read(securityProvider.notifier).setLockStatus(true);
          }
        } else {
          // No last active time (first resume), lock it
          ref.read(securityProvider.notifier).setLockStatus(true);
        }
        
        // Auto trigger auth
        if (ref.read(securityProvider).isAppLocked) {
          ref.read(securityProvider.notifier).authenticate();
        }
      }
    }
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    final isLoggedIn = await CloudAuthService().hasPersistedSession();
    
    // Refresh the app icon badge count on startup
    await NotificationService.updateBadgeCount();

    if (mounted) {
      setState(() {
        _onboardingComplete = onboardingComplete;
        _isLoggedIn = isLoggedIn;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingComplete == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_onboardingComplete!) {
      return const WelcomeScreen();
    }

    // Even if not logged in (skipped sign-in), if onboarding is complete, 
    // we go to main navigation.
    final securityState = ref.watch(securityProvider);
    if (securityState.isAppLocked) {
      return const LockScreen();
    }

    return const MainNavigationScreen();
  }
}
