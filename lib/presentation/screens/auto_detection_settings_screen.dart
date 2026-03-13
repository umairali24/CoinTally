import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:cointally/presentation/notifiers/whitelist_notifier.dart';
import 'package:cointally/core/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class AutoDetectionSettingsScreen extends ConsumerStatefulWidget {
  const AutoDetectionSettingsScreen({super.key});

  @override
  ConsumerState<AutoDetectionSettingsScreen> createState() => _AutoDetectionSettingsScreenState();
}

class _AutoDetectionSettingsScreenState extends ConsumerState<AutoDetectionSettingsScreen> with WidgetsBindingObserver {
  List<AppInfo>? _apps;
  List<AppInfo>? _filteredApps;
  bool _isLoading = true;
  bool _isServiceEnabled = false;
  bool _isBatteryOptimized = false;
  final TextEditingController _searchController = TextEditingController();
  static const _channel = MethodChannel("com.cointally.app/sms_package");

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
    _checkBatteryOptimization();
    _loadApps();
  }

  Future<void> _checkBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (mounted) {
      setState(() => _isBatteryOptimized = !status.isGranted);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
      _checkBatteryOptimization();
    }
  }

  Future<void> _checkPermission() async {
    final granted = await NotificationService().isListenerPermissionGranted();
    if (mounted) {
      setState(() => _isServiceEnabled = granted);
    }
  }

  Future<void> _loadApps() async {
    try {
      final defaultSms = await _channel.invokeMethod<String>("getDefaultSmsPackage");
      ref.read(whitelistProvider.notifier).setDefaultSmsPackage(defaultSms);

      final allApps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        withIcon: true,
        excludeNonLaunchableApps: true,
      );
      
      final List<AppInfo> filtered = allApps.where((app) => app.packageName != defaultSms).toList();

      // Sort: Better UX logic could go here
      filtered.sort((a, b) => a.name!.toLowerCase().compareTo(b.name!.toLowerCase()));

      if (mounted) {
        setState(() {
          _apps = filtered;
          _filteredApps = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterApps(String query) {
    if (_apps == null) return;
    setState(() {
      _filteredApps = _apps!
          .where((app) => app.name!.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final whitelistState = ref.watch(whitelistProvider);
    final whitelistNotifier = ref.read(whitelistProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Auto-Detection', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Battery Optimization Section
          _buildBatterySection(),
          
          // Master Toggle Section
          _buildMasterToggle(),
          
          if (_isServiceEnabled) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
              child: Divider(thickness: 1),
            ),
            
            // SMS Section
            _buildSmsSection(whitelistState, whitelistNotifier),
            
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
              child: Divider(thickness: 1),
            ),

            // App Notifications Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'APP NOTIFICATIONS',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select banking apps to automatically capture transaction details from their notifications.',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),

            // Search & App List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                onChanged: _filterApps,
                style: GoogleFonts.manrope(),
                decoration: InputDecoration(
                  hintText: 'Search banking apps...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Theme.of(context).cardTheme.color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredApps == null || _filteredApps!.isEmpty
                      ? Center(child: Text('No other apps found', style: GoogleFonts.manrope()))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _filteredApps!.length,
                          itemBuilder: (context, index) {
                            final app = _filteredApps![index];
                            final isAllowed = whitelistState.whitelistedPackages.contains(app.packageName);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardTheme.color,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isAllowed 
                                      ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                                      : Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.05),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: app.icon != null 
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.memory(app.icon!, width: 48, height: 48),
                                      )
                                    : CircleAvatar(
                                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                        child: Text(app.name![0]),
                                      ),
                                title: Text(
                                  app.name!,
                                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  app.packageName!,
                                  style: GoogleFonts.manrope(fontSize: 10, color: Colors.grey),
                                ),
                                trailing: Switch.adaptive(
                                  value: isAllowed,
                                  activeColor: Theme.of(context).colorScheme.primary,
                                  onChanged: (_) => whitelistNotifier.toggleApp(app.packageName!),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ] else ...[
            // Service Disabled Message
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_rounded, size: 64, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.1)),
                      const SizedBox(height: 24),
                      Text(
                        'Auto-Detection is disabled',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enable the service above to start detecting transactions from your notifications.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBatterySection() {
    if (!_isBatteryOptimized) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.battery_alert_rounded, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Battery Optimization',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        'Required for background detection',
                        style: GoogleFonts.manrope(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await Permission.ignoreBatteryOptimizations.request();
                    _checkBatteryOptimization();
                  },
                  child: Text(
                    'FIX NOW',
                    style: GoogleFonts.manrope(
                      color: Colors.orange,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterToggle() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isServiceEnabled ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isServiceEnabled ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isServiceEnabled ? Icons.bolt_rounded : Icons.offline_bolt_rounded,
              color: _isServiceEnabled ? Theme.of(context).colorScheme.primary : Colors.grey,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto-Detection Service',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  Text(
                    _isServiceEnabled ? 'Service is active and listening' : 'Service is currently inactive',
                    style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: _isServiceEnabled,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (val) async {
                final message = val 
                    ? 'Taking you to system settings to enable auto-detection...'
                    : 'Taking you to system settings to disable auto-detection...';
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                
                // Open system settings always for the master toggle
                await NotificationService().openSettings();
                
                // We don't manually call _checkPermission here because 
                // the didChangeAppLifecycleState will catch it on resume.
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsSection(WhitelistState state, WhitelistNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SMS TRANSACTIONS',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Icon(Icons.sms_rounded, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Read SMS Alerts',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Monitor your default messages app',
                        style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: state.smsAlertsEnabled,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (val) => notifier.setSmsAlertsEnabled(val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
