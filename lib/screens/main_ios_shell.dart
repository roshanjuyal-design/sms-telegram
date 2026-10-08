import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../services/app_lock_service.dart';
import '../services/battery_helper_service.dart';
import '../services/soundbox_service.dart';
import '../services/update_service.dart';
import '../theme/ios_theme.dart';
import 'app_lock_screen.dart';
import 'ios_monitor_screen.dart';
import 'settings_screen.dart';
import 'soundbox_screen.dart';
import 'transaction_history_screen.dart';

const MethodChannel _mainChannel = MethodChannel('com.example.sms_to_telegram/sms');

class MainIosShell extends StatefulWidget {
  final int initialTab;

  const MainIosShell({super.key, this.initialTab = 0});

  @override
  State<MainIosShell> createState() => _MainIosShellState();
}

class _MainIosShellState extends State<MainIosShell> with WidgetsBindingObserver {
  late CupertinoTabController _tabController;
  int _currentIndex = 0;
  bool _isLocked = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _tabController = CupertinoTabController(initialIndex: widget.initialTab);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addObserver(this);
    _initAppServices();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _checkLockOnPause();
    }
  }

  Future<void> _checkLockOnPause() async {
    final lockEnabled = await AppLockService.isLockEnabled();
    if (lockEnabled && mounted) {
      setState(() => _isLocked = true);
    }
  }

  void _onTabChanged() {
    if (_tabController.index != _currentIndex) {
      setState(() {
        _currentIndex = _tabController.index;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initAppServices() async {
    try {
      final lockEnabled = await AppLockService.isLockEnabled();
      if (mounted) {
        setState(() => _isLocked = lockEnabled);
      }
    } catch (e) {
      debugPrint('Error checking app lock: $e');
    }

    await _requestPermissions();
    await _startForegroundService();
    await BatteryHelperService.startHeartbeatTimer();
    await SoundboxService.init();
    await _checkAndRequestOverlay();
    _checkSilentUpdate();
  }

  Future<void> _checkSilentUpdate() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    try {
      final updateInfo = await UpdateService.checkForUpdate();
      if (mounted && updateInfo != null && updateInfo.hasUpdate) {
        UpdateService.showUpdatePrompt(context, updateInfo);
      }
    } catch (_) {}
  }

  Future<void> _requestPermissions() async {
    try {
      final bool? granted = await _mainChannel.invokeMethod<bool>('requestPermissions');
      debugPrint('iOS Shell: SMS/Notification permissions: $granted');
    } catch (e) {
      debugPrint('Error requesting permissions in iOS Shell: $e');
    }
  }

  Future<void> _startForegroundService() async {
    try {
      await _mainChannel.invokeMethod('startForegroundService');
    } catch (e) {
      debugPrint('Error starting foreground service: $e');
    }
  }

  Future<void> _checkAndRequestOverlay() async {
    try {
      final bool? granted = await _mainChannel.invokeMethod<bool>('checkOverlayPermission');
      if (granted == false) {
        await _mainChannel.invokeMethod('requestOverlayPermission');
      }
    } catch (e) {
      debugPrint('Error checking overlay permission: $e');
    }
  }

  void _navigateToTab(int index) {
    if (index >= 0 && index < 4) {
      setState(() {
        _currentIndex = index;
        _tabController.index = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return AppLockScreen(
        onUnlocked: () {
          setState(() => _isLocked = false);
        },
      );
    }

    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        backgroundColor: IosColors.secondaryBackground.withValues(alpha: 0.88),
        activeColor: IosColors.systemBlue,
        inactiveColor: IosColors.secondaryLabel,
        iconSize: 22,
        height: 54,
        border: const Border(
          top: BorderSide(color: IosColors.separator, width: 0.5),
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.shield_fill),
            label: 'Monitor',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar_alt_fill),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.speaker_2_fill),
            label: 'Soundbox',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.gear_alt_fill),
            label: 'Settings',
          ),
        ],
      ),
      tabBuilder: (BuildContext context, int index) {
        switch (index) {
          case 0:
            return CupertinoTabView(
              builder: (ctx) => IosMonitorScreen(
                onNavigateTab: _navigateToTab,
              ),
            );
          case 1:
            return CupertinoTabView(
              builder: (ctx) => const TransactionHistoryScreen(),
            );
          case 2:
            return CupertinoTabView(
              builder: (ctx) => const SoundboxScreen(),
            );
          case 3:
            return CupertinoTabView(
              builder: (ctx) => const SettingsScreen(),
            );
          default:
            return CupertinoTabView(
              builder: (ctx) => IosMonitorScreen(
                onNavigateTab: _navigateToTab,
              ),
            );
        }
      },
    );
  }
}
