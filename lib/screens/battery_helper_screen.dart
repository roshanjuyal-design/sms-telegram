import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/battery_helper_service.dart';
import '../theme/ios_theme.dart';

class BatteryHelperScreen extends StatefulWidget {
  const BatteryHelperScreen({super.key});

  @override
  State<BatteryHelperScreen> createState() => _BatteryHelperScreenState();
}

class _BatteryHelperScreenState extends State<BatteryHelperScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isBatteryIgnored = false;
  bool _isHeartbeatEnabled = true;
  int _heartbeatInterval = 30;
  bool _isSendingPing = false;

  Map<String, dynamic> _deviceInfo = {};
  Map<String, dynamic> _batteryInfo = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAllStatuses();
    }
  }

  Future<void> _loadAllStatuses() async {
    setState(() => _isLoading = true);

    final isIgnored = await BatteryHelperService.isIgnoringBatteryOptimizations();
    final devInfo = await BatteryHelperService.getDeviceInfo();
    final battInfo = await BatteryHelperService.getBatteryInfo();
    final heartbeatEnabled = await BatteryHelperService.isHeartbeatEnabled();
    final heartbeatInterval = await BatteryHelperService.getHeartbeatIntervalMinutes();

    if (mounted) {
      setState(() {
        _isBatteryIgnored = isIgnored;
        _deviceInfo = devInfo;
        _batteryInfo = battInfo;
        _isHeartbeatEnabled = heartbeatEnabled;
        _heartbeatInterval = heartbeatInterval;
        _isLoading = false;
      });
    }
  }

  String _getBrandSpecificGuide(String manufacturer) {
    final lower = manufacturer.toLowerCase();
    if (lower.contains('xiaomi') || lower.contains('redmi') || lower.contains('poco')) {
      return '1. Turn ON "Auto-start" toggle.\n2. Tap "Battery saver" and select "No restrictions".\n3. Lock the app in Recent Apps overview.';
    } else if (lower.contains('samsung')) {
      return '1. Go to Device Care > Battery > Background usage limits.\n2. Add "InyaTech" to "Never sleeping apps".\n3. Disable "Put unused apps to sleep".';
    } else if (lower.contains('vivo') || lower.contains('iqoo')) {
      return '1. Go to Settings > Battery > Background power consumption.\n2. Find InyaTech and select "High background power usage".\n3. Enable "Auto-start" in Permission management.';
    } else if (lower.contains('oppo') || lower.contains('realme') || lower.contains('oneplus')) {
      return '1. Go to App Management > InyaTech > Battery usage.\n2. Enable "Allow auto-launch" & "Allow background activity".\n3. Lock app in Recent Tasks.';
    } else if (lower.contains('huawei') || lower.contains('honor')) {
      return '1. Go to Battery > App launch > InyaTech.\n2. Switch to "Manage manually" and turn ON Auto-launch, Secondary launch & Run in background.';
    } else {
      return '1. Open App Info > Battery.\n2. Select "Unrestricted" / "Don\'t optimize".\n3. Allow Background Activity & Auto-start if available.';
    }
  }

  Future<void> _requestBatteryOptimization() async {
    await BatteryHelperService.requestIgnoreBatteryOptimizations();
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    await _loadAllStatuses();
  }

  Future<void> _openAutoStart() async {
    await BatteryHelperService.openAutoStartSettings();
  }

  Future<void> _toggleHeartbeat(bool val) async {
    setState(() => _isHeartbeatEnabled = val);
    await BatteryHelperService.setHeartbeatEnabled(val);
  }

  Future<void> _sendTestHeartbeat() async {
    setState(() => _isSendingPing = true);
    final res = await BatteryHelperService.sendHeartbeatPing(isManualTest: true);
    setState(() => _isSendingPing = false);

    final int successCount = res['success'] ?? 0;

    if (mounted) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(successCount > 0 ? 'Heartbeat Sent' : 'Ping Failed'),
          content: Text(
            successCount > 0
                ? 'Live heartbeat ping successfully sent to $successCount Telegram agent(s).'
                : 'Could not send heartbeat ping. Please check Bot Token in Settings.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final manufacturer = _deviceInfo['manufacturer']?.toString() ?? 'Android';
    final model = _deviceInfo['model']?.toString() ?? 'Device';
    final batteryLevel = _batteryInfo['batteryLevel'] is int ? _batteryInfo['batteryLevel'] as int : -1;
    final isCharging = _batteryInfo['isCharging'] as bool? ?? false;
    final brandGuide = _getBrandSpecificGuide(manufacturer);

    return Scaffold(
      backgroundColor: IosColors.systemBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // iOS Large Title Navigation Bar
          CupertinoSliverNavigationBar(
            largeTitle: const Text(
              '24/7 Stability',
              style: TextStyle(
                color: IosColors.label,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.6,
              ),
            ),
            backgroundColor: IosColors.systemBackground.withValues(alpha: 0.8),
            border: const Border(
              bottom: BorderSide(color: IosColors.separator, width: 0.5),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _loadAllStatuses,
              child: const Icon(CupertinoIcons.arrow_clockwise, size: 20, color: IosColors.systemBlue),
            ),
          ),

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CupertinoActivityIndicator(radius: 14),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Device & Health Summary
                    IosGroupedCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: (_isBatteryIgnored ? IosColors.systemGreen : IosColors.systemOrange)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _isBatteryIgnored ? CupertinoIcons.shield_lefthalf_fill : CupertinoIcons.exclamationmark_triangle_fill,
                                  color: _isBatteryIgnored ? IosColors.systemGreen : IosColors.systemOrange,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isBatteryIgnored ? 'System Protected (24/7)' : 'Optimization Needed',
                                      style: TextStyle(
                                        color: _isBatteryIgnored ? IosColors.systemGreen : IosColors.systemOrange,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$manufacturer $model (Battery: ${batteryLevel >= 0 ? '$batteryLevel% ${isCharging ? '⚡' : ''}' : 'Active'})',
                                      style: const TextStyle(
                                        color: IosColors.secondaryLabel,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Android OEMs (Xiaomi, Samsung, Oppo, Vivo) kill background apps to save battery. Follow the steps below to ensure uninterrupted SMS forwarding 24/7.',
                            style: TextStyle(
                              color: IosColors.secondaryLabel,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Section 2: Battery Whitelist Action
                    const IosSectionHeader(title: 'Step 1: Battery Optimization'),
                    IosGroupedCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(CupertinoIcons.battery_25, size: 20, color: IosColors.systemGreen),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Battery Whitelist',
                                  style: TextStyle(
                                    color: IosColors.label,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (_isBatteryIgnored ? IosColors.systemGreen : IosColors.systemOrange)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _isBatteryIgnored ? 'Unrestricted' : 'Optimized',
                                  style: TextStyle(
                                    color: _isBatteryIgnored ? IosColors.systemGreen : IosColors.systemOrange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isBatteryIgnored
                                ? 'App is exempted from Android battery optimizations. Background execution will not be interrupted.'
                                : 'App is currently subject to battery saving. Tap Whitelist below to prevent the OS from killing the service.',
                            style: const TextStyle(color: IosColors.secondaryLabel, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          if (!_isBatteryIgnored)
                            SizedBox(
                              width: double.infinity,
                              child: CupertinoButton.filled(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                borderRadius: BorderRadius.circular(10),
                                onPressed: _requestBatteryOptimization,
                                child: const Text(
                                  'Whitelist App in Battery Settings',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Section 3: OEM Auto-Start Configuration
                    const IosSectionHeader(title: 'Step 2: OEM Auto-Start Guide'),
                    IosGroupedCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(CupertinoIcons.gear_alt_fill, size: 20, color: IosColors.systemIndigo),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Instructions for $manufacturer',
                                  style: const TextStyle(
                                    color: IosColors.label,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: IosColors.tertiaryBackground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              brandGuide,
                              style: const TextStyle(
                                color: IosColors.label,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              color: IosColors.systemIndigo,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              borderRadius: BorderRadius.circular(10),
                              onPressed: _openAutoStart,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.arrow_up_right_square, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'Open OEM Auto-Start Settings',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Section 4: 24/7 Heartbeat Ping
                    const IosSectionHeader(title: 'Step 3: Telegram Heartbeat Ping'),
                    IosGroupedCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(CupertinoIcons.heart_fill, size: 20, color: IosColors.systemRed),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Heartbeat Status',
                                  style: TextStyle(
                                    color: IosColors.label,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              CupertinoSwitch(
                                value: _isHeartbeatEnabled,
                                activeTrackColor: IosColors.systemGreen,
                                onChanged: _toggleHeartbeat,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Periodically sends a lightweight status ping every $_heartbeatInterval minutes to Telegram to confirm that the app is alive and receiving SMS messages.',
                            style: const TextStyle(color: IosColors.secondaryLabel, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              color: IosColors.tertiaryBackground,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              borderRadius: BorderRadius.circular(10),
                              onPressed: _isSendingPing ? null : _sendTestHeartbeat,
                              child: _isSendingPing
                                  ? const CupertinoActivityIndicator(radius: 8)
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(CupertinoIcons.paperplane_fill, size: 16, color: IosColors.systemBlue),
                                        SizedBox(width: 8),
                                        Text(
                                          'Send Test Heartbeat Ping',
                                          style: TextStyle(color: IosColors.label, fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
