import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/telegram_recipient.dart';
import '../services/app_lock_service.dart';
import '../services/battery_helper_service.dart';
import '../services/eod_report_service.dart';
import '../services/settings_service.dart';
import '../services/update_service.dart';
import '../theme/ios_theme.dart';
import 'battery_helper_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  final TextEditingController _botTokenController = TextEditingController();
  bool _isBotTokenObscured = true;
  bool _isLoading = true;
  bool _isVerifyingBot = false;
  String? _botVerificationStatus;
  bool _isBotVerified = false;
  bool _isBatteryIgnored = false;
  int _heartbeatInterval = 30;

  bool _isCheckingUpdate = false;
  String _githubRepo = UpdateService.defaultRepo;
  bool _hasGithubToken = false;

  bool _isEodEnabled = true;
  int _eodHour = 23;
  int _eodMinute = 59;
  String? _lastEodSentDate;
  bool _isSendingTestEod = false;

  bool _isLockEnabled = true;
  bool _isBiometricsEnabled = true;
  bool _canUseBiometrics = false;

  List<TelegramRecipient> _recipients = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    _botTokenController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBatteryStatus();
    }
  }

  Future<void> _checkBatteryStatus() async {
    final isIgnored = await BatteryHelperService.isIgnoringBatteryOptimizations();
    if (mounted) {
      setState(() => _isBatteryIgnored = isIgnored);
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final token = await SettingsService.getBotToken();
    final recipients = await SettingsService.getRecipients();
    final isBattery = await BatteryHelperService.isIgnoringBatteryOptimizations();
    final interval = await BatteryHelperService.getHeartbeatIntervalMinutes();
    final repo = await UpdateService.getGithubRepo();
    final ghToken = await UpdateService.getGithubToken();
    final isEod = await EodReportService.isEodEnabled();
    final eHour = await EodReportService.getEodHour();
    final eMin = await EodReportService.getEodMinute();
    final lastEod = await EodReportService.getLastSentDate();
    final isLock = await AppLockService.isLockEnabled();
    final isBio = await AppLockService.isBiometricsEnabled();
    final canBio = await AppLockService.canUseBiometrics();

    _botTokenController.text = token;
    if (mounted) {
      setState(() {
        _recipients = recipients;
        _isBatteryIgnored = isBattery;
        _heartbeatInterval = interval;
        _githubRepo = repo;
        _hasGithubToken = ghToken.isNotEmpty;
        _isEodEnabled = isEod;
        _eodHour = eHour;
        _eodMinute = eMin;
        _lastEodSentDate = lastEod;
        _isLockEnabled = isLock;
        _isBiometricsEnabled = isBio;
        _canUseBiometrics = canBio;
        _isLoading = false;
      });
    }

    if (token.isNotEmpty) {
      _verifyBotToken(showDialog: false);
    }
  }

  Future<void> _saveBotToken() async {
    final token = _botTokenController.text.trim();
    await SettingsService.setBotToken(token);
    _showIosAlert(title: 'Token Saved', message: 'Telegram Bot Token has been saved.');
  }

  Future<void> _verifyBotToken({bool showDialog = true}) async {
    final token = _botTokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _botVerificationStatus = 'Please enter a Bot Token';
        _isBotVerified = false;
      });
      return;
    }

    setState(() {
      _isVerifyingBot = true;
      _botVerificationStatus = null;
    });

    final res = await SettingsService.verifyBotToken(token);

    if (!mounted) return;

    setState(() {
      _isVerifyingBot = false;
      if (res['success'] == true) {
        _isBotVerified = true;
        final botName = res['botName'] ?? 'Bot';
        final username = res['username'] != null && res['username'].toString().isNotEmpty
            ? '@${res['username']}'
            : '';
        _botVerificationStatus = 'Connected: $botName $username';
      } else {
        _isBotVerified = false;
        _botVerificationStatus = res['error']?.toString() ?? 'Failed to connect';
      }
    });

    if (showDialog) {
      _showIosAlert(
        title: _isBotVerified ? 'Verification Successful' : 'Verification Failed',
        message: _botVerificationStatus ?? '',
      );
    }
  }

  Future<void> _toggleRecipient(TelegramRecipient recipient) async {
    final updated = recipient.copyWith(isEnabled: !recipient.isEnabled);
    await SettingsService.saveRecipient(updated);
    await _loadSettings();
  }

  Future<void> _deleteRecipient(String id) async {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Agent?'),
        content: const Text('Are you sure you want to remove this Telegram recipient?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await SettingsService.deleteRecipient(id);
              await _loadSettings();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _testRecipient(TelegramRecipient recipient) async {
    final botToken = await SettingsService.getBotToken();
    if (botToken.isEmpty) {
      _showIosAlert(title: 'Error', message: 'Please configure and save Bot Token first.');
      return;
    }

    final success = await SettingsService.sendTestMessageToRecipient(
      botToken: botToken,
      chatId: recipient.chatId,
    );

    if (mounted) {
      _showIosAlert(
        title: success ? 'Test Sent' : 'Delivery Failed',
        message: success
            ? 'Test message sent to ${recipient.name} (${recipient.chatId}).'
            : 'Could not send test message to ${recipient.chatId}. Please check Bot Token and permissions.',
      );
    }
  }

  Future<void> _showAddRecipientDialog([TelegramRecipient? existing]) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final chatIdController = TextEditingController(text: existing?.chatId ?? '');

    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(existing == null ? 'Add Telegram Agent' : 'Edit Agent'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: nameController,
                placeholder: 'Agent Name (e.g. Roshan / Main Group)',
                placeholderStyle: const TextStyle(color: IosColors.secondaryLabel, fontSize: 14),
                style: const TextStyle(color: IosColors.label, fontSize: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: IosColors.tertiaryBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: chatIdController,
                placeholder: 'Chat ID (e.g. 523321456 or -100...)',
                placeholderStyle: const TextStyle(color: IosColors.secondaryLabel, fontSize: 14),
                style: const TextStyle(color: IosColors.label, fontSize: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: IosColors.tertiaryBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Save'),
            onPressed: () async {
              final name = nameController.text.trim();
              final chatId = chatIdController.text.trim();
              if (name.isNotEmpty && chatId.isNotEmpty) {
                final nav = Navigator.of(ctx);
                final rec = TelegramRecipient(
                  id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  chatId: chatId,
                  isEnabled: existing?.isEnabled ?? true,
                );
                await SettingsService.saveRecipient(rec);
                nav.pop();
                if (mounted) {
                  await _loadSettings();
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    setState(() => _isCheckingUpdate = true);
    final updateInfo = await UpdateService.checkForUpdate();
    if (mounted) {
      setState(() => _isCheckingUpdate = false);
    }

    if (!mounted) return;

    if (updateInfo != null && updateInfo.hasUpdate) {
      UpdateService.showUpdatePrompt(context, updateInfo);
    } else {
      _showIosAlert(
        title: 'Up to Date',
        message: 'You are running the latest version (v${UpdateService.currentVersion}).',
      );
    }
  }

  Future<void> _showGithubConfigDialog() async {
    final repoController = TextEditingController(text: _githubRepo);
    final currentToken = await UpdateService.getGithubToken();
    final tokenController = TextEditingController(text: currentToken);

    if (!mounted) return;

    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('GitHub Releases Setup'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Repository (owner/repo):',
                style: TextStyle(fontSize: 12, color: IosColors.secondaryLabel),
              ),
              const SizedBox(height: 4),
              CupertinoTextField(
                controller: repoController,
                placeholder: 'username/sms_to_telegram',
                placeholderStyle: const TextStyle(color: IosColors.secondaryLabel, fontSize: 13),
                style: const TextStyle(color: IosColors.label, fontSize: 13),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: IosColors.tertiaryBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Classic Token (Optional for Private Repos):',
                style: TextStyle(fontSize: 12, color: IosColors.secondaryLabel),
              ),
              const SizedBox(height: 4),
              CupertinoTextField(
                controller: tokenController,
                obscureText: true,
                placeholder: 'ghp_xxxx or github_pat_xxxx',
                placeholderStyle: const TextStyle(color: IosColors.secondaryLabel, fontSize: 13),
                style: const TextStyle(color: IosColors.label, fontSize: 13),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: IosColors.tertiaryBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Save'),
            onPressed: () async {
              final newRepo = repoController.text.trim();
              final newToken = tokenController.text.trim();
              if (newRepo.isNotEmpty) {
                final nav = Navigator.of(ctx);
                await UpdateService.setGithubRepo(newRepo);
                await UpdateService.setGithubToken(newToken);
                nav.pop();
                if (mounted) {
                  await _loadSettings();
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showIosAlert({required String title, required String message}) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _showHeartbeatPicker() async {
    const intervals = [15, 30, 60, 120];
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Select Heartbeat Interval'),
        message: const Text('Periodic ping sent to Telegram to ensure 24/7 background stability.'),
        actions: intervals.map((int m) {
          final label = m < 60 ? '$m Minutes' : '${m ~/ 60} Hour${(m ~/ 60) > 1 ? 's' : ''}';
          return CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await BatteryHelperService.setHeartbeatIntervalMinutes(m);
              setState(() => _heartbeatInterval = m);
            },
            child: Text(label),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  String _formatEodTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final mStr = minute.toString().padLeft(2, '0');
    return '$h12:$mStr $period';
  }

  Future<void> _toggleEod(bool value) async {
    await EodReportService.setEodEnabled(value);
    setState(() => _isEodEnabled = value);
  }

  Future<void> _pickEodTime() async {
    Duration tempDuration = Duration(hours: _eodHour, minutes: _eodMinute);
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: IosColors.secondaryBackground,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                color: IosColors.tertiaryBackground,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('Cancel', style: TextStyle(color: IosColors.systemRed)),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    const Text('EOD Report Time', style: TextStyle(color: IosColors.label, fontWeight: FontWeight.bold, fontSize: 16)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('Done', style: TextStyle(color: IosColors.systemBlue, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final h = tempDuration.inHours % 24;
                        final m = tempDuration.inMinutes % 60;
                        await EodReportService.setEodTime(h, m);
                        setState(() {
                          _eodHour = h;
                          _eodMinute = m;
                        });
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hm,
                  initialTimerDuration: tempDuration,
                  onTimerDurationChanged: (d) => tempDuration = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendTestEodReport() async {
    setState(() => _isSendingTestEod = true);
    final result = await EodReportService.sendEodReport(isManualTest: true);
    if (!mounted) return;
    setState(() => _isSendingTestEod = false);
    final sent = result['sent'] ?? 0;
    final failed = result['failed'] ?? 0;
    _showIosAlert(
      title: 'EOD Report Sent! 🌙',
      message: 'Settlement summary sent to $sent active recipient(s)${failed > 0 ? ' ($failed failed)' : ''}. Check your Telegram chat!',
    );
  }

  Future<void> _toggleAppLock(bool value) async {
    await AppLockService.setLockEnabled(value);
    setState(() => _isLockEnabled = value);
  }

  Future<void> _toggleBiometrics(bool value) async {
    await AppLockService.setBiometricsEnabled(value);
    setState(() => _isBiometricsEnabled = value);
  }

  Future<void> _showChangePinDialog() async {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String error = '';

    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: const Text('Change 4-Digit Passcode'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                const Text(
                  'Default PIN is 5440.',
                  style: TextStyle(fontSize: 12, color: IosColors.secondaryLabel),
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: currentPinController,
                  placeholder: 'Current PIN',
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: const TextStyle(color: IosColors.label),
                  placeholderStyle: const TextStyle(color: IosColors.secondaryLabel),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: newPinController,
                  placeholder: 'New 4-Digit PIN',
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: const TextStyle(color: IosColors.label),
                  placeholderStyle: const TextStyle(color: IosColors.secondaryLabel),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: confirmPinController,
                  placeholder: 'Confirm New PIN',
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: const TextStyle(color: IosColors.label),
                  placeholderStyle: const TextStyle(color: IosColors.secondaryLabel),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(error, style: const TextStyle(color: IosColors.systemRed, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Save PIN'),
              onPressed: () async {
                final cur = currentPinController.text.trim();
                final nw = newPinController.text.trim();
                final conf = confirmPinController.text.trim();

                final isCurValid = await AppLockService.verifyPin(cur);
                if (!isCurValid) {
                  setDialogState(() => error = 'Incorrect current PIN');
                  return;
                }
                if (nw.length != 4 || int.tryParse(nw) == null) {
                  setDialogState(() => error = 'New PIN must be 4 digits');
                  return;
                }
                if (nw != conf) {
                  setDialogState(() => error = 'PINs do not match');
                  return;
                }

                await AppLockService.setPin(nw);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  _showIosAlert(
                    title: 'PIN Updated! 🔐',
                    message: 'Your new 4-digit passcode has been saved successfully.',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
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
              'Settings',
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
              onPressed: _loadSettings,
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
                    // Section 1: Telegram Bot Configuration
                    const IosSectionHeader(title: 'Telegram Bot Configuration'),
                    IosGroupedCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BOT TOKEN',
                            style: TextStyle(
                              color: IosColors.secondaryLabel,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CupertinoTextField(
                            controller: _botTokenController,
                            obscureText: _isBotTokenObscured,
                            placeholder: '123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ',
                            placeholderStyle: const TextStyle(color: IosColors.secondaryLabel, fontSize: 13),
                            style: const TextStyle(color: IosColors.label, fontSize: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              color: IosColors.tertiaryBackground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            suffix: CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(
                                _isBotTokenObscured ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                                size: 18,
                                color: IosColors.secondaryLabel,
                              ),
                              onPressed: () {
                                setState(() => _isBotTokenObscured = !_isBotTokenObscured);
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_botVerificationStatus != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isBotVerified
                                    ? IosColors.systemGreen.withValues(alpha: 0.15)
                                    : IosColors.systemRed.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isBotVerified ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.exclamationmark_circle_fill,
                                    size: 16,
                                    color: _isBotVerified ? IosColors.systemGreen : IosColors.systemRed,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _botVerificationStatus!,
                                      style: TextStyle(
                                        color: _isBotVerified ? IosColors.systemGreen : IosColors.systemRed,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton(
                                  color: IosColors.tertiaryBackground,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  borderRadius: BorderRadius.circular(10),
                                  onPressed: _isVerifyingBot ? null : () => _verifyBotToken(showDialog: true),
                                  child: _isVerifyingBot
                                      ? const CupertinoActivityIndicator(radius: 8)
                                      : const Text(
                                          'Verify Bot',
                                          style: TextStyle(color: IosColors.systemBlue, fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: CupertinoButton.filled(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  borderRadius: BorderRadius.circular(10),
                                  onPressed: _saveBotToken,
                                  child: const Text(
                                    'Save Token',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Section 2: Forwarding Recipients
                    IosSectionHeader(
                      title: 'Forwarding Agents & Groups (${_recipients.length})',
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _showAddRecipientDialog(),
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.plus_circle_fill, size: 16, color: IosColors.systemBlue),
                            SizedBox(width: 4),
                            Text('Add Agent', style: TextStyle(fontSize: 13, color: IosColors.systemBlue)),
                          ],
                        ),
                      ),
                    ),

                    if (_recipients.isEmpty)
                      IosGroupedCard(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(CupertinoIcons.person_3_fill, size: 36, color: IosColors.tertiaryLabel),
                              const SizedBox(height: 10),
                              const Text(
                                'No Telegram Agents Added',
                                style: TextStyle(color: IosColors.label, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Add your Telegram Chat ID or Group ID to receive SMS alerts.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: IosColors.secondaryLabel, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              CupertinoButton(
                                color: IosColors.systemBlue,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                borderRadius: BorderRadius.circular(8),
                                onPressed: () => _showAddRecipientDialog(),
                                child: const Text('Add First Agent', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      IosGroupedCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            for (int i = 0; i < _recipients.length; i++) ...[
                              if (i > 0) const IosDivider(indent: 52),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: (_recipients[i].isEnabled ? IosColors.systemBlue : IosColors.tertiaryLabel)
                                            .withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.paperplane_fill,
                                        size: 16,
                                        color: _recipients[i].isEnabled ? IosColors.systemBlue : IosColors.secondaryLabel,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _recipients[i].name,
                                            style: const TextStyle(
                                              color: IosColors.label,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'ID: ${_recipients[i].chatId}',
                                            style: const TextStyle(
                                              color: IosColors.secondaryLabel,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    CupertinoButton(
                                      padding: const EdgeInsets.all(6),
                                      child: const Icon(CupertinoIcons.paperplane, size: 18, color: IosColors.systemBlue),
                                      onPressed: () => _testRecipient(_recipients[i]),
                                    ),
                                    CupertinoButton(
                                      padding: const EdgeInsets.all(6),
                                      child: const Icon(CupertinoIcons.trash, size: 18, color: IosColors.systemRed),
                                      onPressed: () => _deleteRecipient(_recipients[i].id),
                                    ),
                                    CupertinoSwitch(
                                      value: _recipients[i].isEnabled,
                                      onChanged: (val) => _toggleRecipient(_recipients[i]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    // Section 3: 24/7 Stability & Background Monitoring
                    const IosSectionHeader(title: '24/7 Stability & Background Run'),
                    IosGroupedCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          IosListTile(
                            leadingIcon: CupertinoIcons.battery_25,
                            iconColor: _isBatteryIgnored ? IosColors.systemGreen : IosColors.systemOrange,
                            title: 'Battery Whitelist',
                            subtitle: _isBatteryIgnored ? 'Unrestricted Background Run' : 'Optimized (Tap to Whitelist)',
                            showChevron: true,
                            onTap: () async {
                              await BatteryHelperService.requestIgnoreBatteryOptimizations();
                              await _checkBatteryStatus();
                            },
                          ),
                          const IosDivider(indent: 52),
                          IosListTile(
                            leadingIcon: CupertinoIcons.gear_alt_fill,
                            iconColor: IosColors.systemIndigo,
                            title: 'OEM Auto-Start Setup',
                            subtitle: 'Xiaomi, Vivo, Oppo, OnePlus Guides',
                            showChevron: true,
                            onTap: () {
                              Navigator.of(context).push(
                                CupertinoPageRoute<void>(
                                  builder: (ctx) => const BatteryHelperScreen(),
                                ),
                              );
                            },
                          ),
                          const IosDivider(indent: 52),
                          IosListTile(
                            leadingIcon: CupertinoIcons.heart_circle_fill,
                            iconColor: IosColors.systemRed,
                            title: 'Heartbeat Ping Interval',
                            subtitle: 'Every $_heartbeatInterval minutes',
                            showChevron: true,
                            onTap: _showHeartbeatPicker,
                          ),
                        ],
                      ),
                    ),

                    // Section 4: Night EOD Settlement Report
                    const IosSectionHeader(title: 'Automatic Night EOD Settlement (Telegram)'),
                    IosGroupedCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          IosListTile(
                            leadingIcon: CupertinoIcons.moon_stars_fill,
                            iconColor: IosColors.systemPurple,
                            title: 'Auto EOD Settlement Report',
                            subtitle: 'Sends daily collection summary to Telegram at 11:59 PM',
                            trailing: CupertinoSwitch(
                              value: _isEodEnabled,
                              activeTrackColor: IosColors.systemGreen,
                              onChanged: _toggleEod,
                            ),
                          ),
                          if (_isEodEnabled) ...[
                            const IosDivider(indent: 52),
                            IosListTile(
                              leadingIcon: CupertinoIcons.clock_fill,
                              iconColor: IosColors.systemBlue,
                              title: 'Scheduled Dispatch Time',
                              subtitle: '${_formatEodTime(_eodHour, _eodMinute)} (Daily)',
                              showChevron: true,
                              onTap: _pickEodTime,
                            ),
                            const IosDivider(indent: 52),
                            IosListTile(
                              leadingIcon: CupertinoIcons.paperplane_fill,
                              iconColor: IosColors.systemGreen,
                              title: 'Send Test EOD Report Now',
                              subtitle: 'Preview today\'s settlement summary on Telegram',
                              trailing: _isSendingTestEod
                                  ? const CupertinoActivityIndicator(radius: 8)
                                  : CupertinoButton(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      color: IosColors.tertiaryBackground,
                                      borderRadius: BorderRadius.circular(8),
                                      onPressed: _sendTestEodReport,
                                      child: const Text('Send Test', style: TextStyle(fontSize: 12, color: IosColors.systemGreen, fontWeight: FontWeight.w600)),
                                    ),
                              onTap: _isSendingTestEod ? null : _sendTestEodReport,
                            ),
                            const IosDivider(indent: 52),
                            IosListTile(
                              leadingIcon: CupertinoIcons.checkmark_seal_fill,
                              iconColor: IosColors.systemTeal,
                              title: 'Last Report Status',
                              subtitle: _lastEodSentDate != null
                                  ? 'Sent for $_lastEodSentDate'
                                  : 'Waiting for next schedule (Tonight)',
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Section 5: App Security & Passcode Lock (PIN 5440)
                    const IosSectionHeader(title: 'App Security & Passcode Lock'),
                    IosGroupedCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          IosListTile(
                            leadingIcon: CupertinoIcons.lock_shield_fill,
                            iconColor: IosColors.systemBlue,
                            title: 'Passcode Protection',
                            subtitle: 'Require 4-digit PIN (Default: 5440)',
                            trailing: CupertinoSwitch(
                              value: _isLockEnabled,
                              activeTrackColor: IosColors.systemGreen,
                              onChanged: _toggleAppLock,
                            ),
                          ),
                          if (_isLockEnabled) ...[
                            const IosDivider(indent: 52),
                            IosListTile(
                              leadingIcon: CupertinoIcons.padlock_solid,
                              iconColor: IosColors.systemOrange,
                              title: 'Change 4-Digit PIN',
                              subtitle: 'Current PIN: • • • • (Tap to change)',
                              showChevron: true,
                              onTap: _showChangePinDialog,
                            ),
                            if (_canUseBiometrics) ...[
                              const IosDivider(indent: 52),
                              IosListTile(
                                leadingIcon: CupertinoIcons.viewfinder,
                                iconColor: IosColors.systemGreen,
                                title: 'Biometric Unlock',
                                subtitle: 'Fingerprint / Face ID unlock',
                                trailing: CupertinoSwitch(
                                  value: _isBiometricsEnabled,
                                  activeTrackColor: IosColors.systemGreen,
                                  onChanged: _toggleBiometrics,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),

                    // Section 6: In-App Updates & GitHub Releases
                    const IosSectionHeader(title: 'In-App Auto-Updates (GitHub Releases)'),
                    IosGroupedCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          IosListTile(
                            leadingIcon: CupertinoIcons.arrow_down_circle_fill,
                            iconColor: IosColors.systemBlue,
                            title: 'Check for Updates',
                            subtitle: 'Current: v${UpdateService.currentVersion}',
                            trailing: _isCheckingUpdate
                                ? const CupertinoActivityIndicator(radius: 8)
                                : CupertinoButton(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    color: IosColors.tertiaryBackground,
                                    borderRadius: BorderRadius.circular(8),
                                    onPressed: _checkForUpdate,
                                    child: const Text('Check', style: TextStyle(fontSize: 12, color: IosColors.systemBlue, fontWeight: FontWeight.w600)),
                                  ),
                            onTap: _isCheckingUpdate ? null : _checkForUpdate,
                          ),
                          const IosDivider(indent: 52),
                          IosListTile(
                            leadingIcon: CupertinoIcons.cloud_download_fill,
                            iconColor: IosColors.systemIndigo,
                            title: 'GitHub Repository',
                            subtitle: _githubRepo,
                            showChevron: true,
                            onTap: _showGithubConfigDialog,
                          ),
                          const IosDivider(indent: 52),
                          IosListTile(
                            leadingIcon: CupertinoIcons.lock_shield_fill,
                            iconColor: _hasGithubToken ? IosColors.systemGreen : IosColors.secondaryLabel,
                            title: 'GitHub Access Token',
                            subtitle: _hasGithubToken ? 'Configured (Private Repo Access)' : 'None (Public Repo Access)',
                            showChevron: true,
                            onTap: _showGithubConfigDialog,
                          ),
                        ],
                      ),
                    ),

                    // Section 5: System Info & Footer
                    const IosSectionHeader(title: 'About System'),
                    IosGroupedCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          const IosListTile(
                            leadingIcon: CupertinoIcons.app_badge_fill,
                            iconColor: IosColors.systemBlue,
                            title: 'InyaTech SMS Forwarder',
                            subtitle: 'Version 2.0 (iOS Edition)',
                          ),
                          const IosDivider(indent: 52),
                          const IosListTile(
                            leadingIcon: CupertinoIcons.person_badge_plus_fill,
                            iconColor: IosColors.systemTeal,
                            title: 'Developer',
                            subtitle: 'Roshan Juyal',
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
