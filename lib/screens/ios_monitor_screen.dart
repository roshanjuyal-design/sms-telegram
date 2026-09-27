import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/battery_helper_service.dart';
import '../services/settings_service.dart';
import '../services/soundbox_service.dart';
import '../services/transaction_history_service.dart';
import '../theme/ios_theme.dart';

class IosMonitorScreen extends StatefulWidget {
  final Function(int tabIndex) onNavigateTab;

  const IosMonitorScreen({super.key, required this.onNavigateTab});

  @override
  State<IosMonitorScreen> createState() => _IosMonitorScreenState();
}

class _IosMonitorScreenState extends State<IosMonitorScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isBatteryIgnored = false;
  bool _isSoundboxEnabled = true;
  int _activeAgentsCount = 0;
  bool _isBotConfigured = false;
  bool _isTesting = false;
  double _todayTotal = 0.0;
  int _todayCount = 0;
  String _soundboxLanguage = SoundboxService.langTelugu;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    final botToken = await SettingsService.getBotToken();
    final activeChatIds = await SettingsService.getActiveChatIds();
    final isBatteryIgnored = await BatteryHelperService.isIgnoringBatteryOptimizations();
    final soundboxEnabled = await SoundboxService.isEnabled();
    final soundboxLang = await SoundboxService.getLanguage();
    final stats = await TransactionHistoryService.getStats();

    if (mounted) {
      setState(() {
        _isBotConfigured = botToken.trim().isNotEmpty;
        _activeAgentsCount = activeChatIds.length;
        _isBatteryIgnored = isBatteryIgnored;
        _isSoundboxEnabled = soundboxEnabled;
        _soundboxLanguage = soundboxLang;
        _todayTotal = (stats['todayTotal'] is num) ? (stats['todayTotal'] as num).toDouble() : 0.0;
        _todayCount = (stats['todayForwardedCount'] is int) ? (stats['todayForwardedCount'] as int) : 0;
        _isLoading = false;
      });
    }
  }

  String _getLangDisplay(String code) {
    switch (code) {
      case SoundboxService.langTelugu:
        return 'తెలుగు';
      case SoundboxService.langHindi:
        return 'हिंदी';
      case SoundboxService.langEnglishIndia:
        return 'English (IN)';
      default:
        return 'English';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IosColors.systemBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // iOS Large Title Navigation Bar
          CupertinoSliverNavigationBar(
            largeTitle: const Text(
              'InyaTech',
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
              onPressed: _refreshStatus,
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
                padding: const EdgeInsets.only(top: 8, bottom: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: System Status Banner
                    IosGroupedCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: IosColors.systemGreen,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x6630D158),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'System Active',
                                style: TextStyle(
                                  color: IosColors.label,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: IosColors.systemGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '24/7 Monitoring',
                                  style: TextStyle(
                                    color: IosColors.systemGreen,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Incoming Union Bank SMS messages are automatically parsed, forwarded to Telegram, and announced via Voice Soundbox.',
                            style: TextStyle(
                              color: IosColors.secondaryLabel,
                              fontSize: 13,
                              height: 1.4,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 4-Tile Quick Metric Grid
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatusTile(
                                  icon: CupertinoIcons.shield_fill,
                                  title: 'Foreground',
                                  subtitle: 'Running',
                                  color: IosColors.systemGreen,
                                  onTap: () => widget.onNavigateTab(3), // Settings
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatusTile(
                                  icon: CupertinoIcons.paperplane_fill,
                                  title: 'Telegram',
                                  subtitle: _isBotConfigured ? '$_activeAgentsCount Agent${_activeAgentsCount > 1 ? 's' : ''}' : 'Setup',
                                  color: IosColors.systemBlue,
                                  onTap: () => widget.onNavigateTab(3), // Settings
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatusTile(
                                  icon: CupertinoIcons.battery_25,
                                  title: 'Battery',
                                  subtitle: _isBatteryIgnored ? 'Unrestricted' : 'Optimize',
                                  color: _isBatteryIgnored ? IosColors.systemGreen : IosColors.systemOrange,
                                  onTap: () => widget.onNavigateTab(3), // Settings
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatusTile(
                                  icon: CupertinoIcons.speaker_2_fill,
                                  title: 'Soundbox',
                                  subtitle: _isSoundboxEnabled ? _getLangDisplay(_soundboxLanguage) : 'Off',
                                  color: _isSoundboxEnabled ? IosColors.systemPurple : IosColors.tertiaryLabel,
                                  onTap: () => widget.onNavigateTab(2), // Soundbox
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const IosSectionHeader(title: "Today's Business"),

                    // Section 2: Today's Collection Card (Tap to View History)
                    IosGroupedCard(
                      padding: const EdgeInsets.all(18),
                      onTap: () => widget.onNavigateTab(1), // History
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: IosColors.systemGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              CupertinoIcons.money_dollar_circle_fill,
                              color: IosColors.systemGreen,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Today's Credited Amount",
                                  style: TextStyle(
                                    color: IosColors.secondaryLabel,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${_todayTotal.toStringAsFixed(_todayTotal.truncateToDouble() == _todayTotal ? 0 : 2)}',
                                  style: const TextStyle(
                                    color: IosColors.label,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$_todayCount transaction${_todayCount != 1 ? 's' : ''} processed today',
                                  style: const TextStyle(
                                    color: IosColors.secondaryLabel,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            CupertinoIcons.chevron_right,
                            color: IosColors.tertiaryLabel,
                            size: 18,
                          ),
                        ],
                      ),
                    ),

                    const IosSectionHeader(title: 'Quick Actions'),

                    // Section 3: Test Buttons
                    IosGroupedCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              borderRadius: BorderRadius.circular(12),
                              onPressed: _isTesting
                                  ? null
                                  : () async {
                                      setState(() => _isTesting = true);
                                      const sampleSms =
                                          'UPI payment of Rs. 1000 received from scharan1631@axl on 01-SEP-2026 11:31:16: with transaction ID 046661256251 - Union Bank of India.';

                                      // Send to Telegram
                                      await sendToTelegram(parsePaymentSms(sampleSms));

                                      // Add log
                                      await TransactionHistoryService.addLog(
                                        TransactionHistoryService.createLogFromSms(
                                          rawBody: sampleSms,
                                          sender: 'VK-UBIN',
                                          isForwarded: true,
                                          statusReason: 'Test forwarded to Telegram & Soundbox',
                                        ),
                                      );

                                      // Announce
                                      await SoundboxService.announcePayment(
                                        amount: '1000',
                                        sender: 'scharan1631',
                                        bank: 'Union Bank',
                                      );

                                      setState(() => _isTesting = false);
                                      await _refreshStatus();

                                      if (context.mounted) {
                                        showCupertinoDialog<void>(
                                          context: context,
                                          builder: (ctx) => CupertinoAlertDialog(
                                            title: const Text('Test Successful'),
                                            content: Text(
                                              'Test SMS forwarded to $_activeAgentsCount agent(s) and announced via Voice Soundbox.',
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
                                    },
                              child: _isTesting
                                  ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(CupertinoIcons.play_circle_fill, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Test Payment Alert & Voice',
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              color: IosColors.tertiaryBackground,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              borderRadius: BorderRadius.circular(12),
                              onPressed: () async {
                                final res = await BatteryHelperService.sendHeartbeatPing(isManualTest: true);
                                if (context.mounted) {
                                  showCupertinoDialog<void>(
                                    context: context,
                                    builder: (ctx) => CupertinoAlertDialog(
                                      title: const Text('Heartbeat Ping Sent'),
                                      content: Text(
                                        'Sent live system heartbeat to ${res['success']} Telegram agent(s).',
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
                              },
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.heart_fill, size: 18, color: IosColors.systemRed),
                                  SizedBox(width: 8),
                                  Text(
                                    'Send Heartbeat Ping Now',
                                    style: TextStyle(
                                      color: IosColors.label,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Section 4: iOS Minimalist Footer
                    const SizedBox(height: 24),
                    const Center(
                      child: Column(
                        children: [
                          Text(
                            'InyaTech SMS Forwarder',
                            style: TextStyle(
                              color: IosColors.tertiaryLabel,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Developed by Roshan Juyal',
                            style: TextStyle(
                              color: IosColors.quaternaryLabel,
                              fontSize: 11,
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

  Widget _buildStatusTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: IosColors.tertiaryBackground.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IosColors.separator, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: IosColors.secondaryLabel,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: IosColors.label,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
