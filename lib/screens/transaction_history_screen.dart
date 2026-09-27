import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction_log.dart';
import '../services/soundbox_service.dart';
import '../services/transaction_history_service.dart';
import '../theme/ios_theme.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  bool _isLoading = true;
  List<TransactionLog> _allLogs = [];
  Map<String, dynamic> _stats = {};
  String _searchQuery = '';
  int _selectedSegment = 0; // 0: All, 1: Credited, 2: Filtered
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLogsAndStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogsAndStats() async {
    setState(() => _isLoading = true);
    final logs = await TransactionHistoryService.getLogs();
    final stats = await TransactionHistoryService.getStats();

    if (mounted) {
      setState(() {
        _allLogs = logs;
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  List<TransactionLog> get _filteredLogs {
    return _allLogs.where((log) {
      if (_selectedSegment == 1 && log.status != TransactionStatus.forwarded) {
        return false;
      }
      if (_selectedSegment == 2 && log.status != TransactionStatus.filtered) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesSender = log.sender.toLowerCase().contains(query);
        final matchesAmount = log.formattedAmount.toLowerCase().contains(query);
        final matchesTxn = log.txnId.toLowerCase().contains(query);
        final matchesBody = log.rawBody.toLowerCase().contains(query);
        return matchesSender || matchesAmount || matchesTxn || matchesBody;
      }

      return true;
    }).toList();
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    if (isToday) {
      return 'Today, $hour:$minute';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $hour:$minute';
  }

  Future<void> _showMoreOptions() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Transaction Logs Actions'),
        message: const Text('Export logs or manage local transaction storage.'),
        actions: [
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.share, size: 18, color: IosColors.systemBlue),
                SizedBox(width: 8),
                Text('Copy All as CSV / Text'),
              ],
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final csv = await TransactionHistoryService.exportLogsAsCsv();
              await Clipboard.setData(ClipboardData(text: csv));
              if (mounted) {
                _showIosAlert(
                  title: 'Copied to Clipboard',
                  message: 'Full transaction logs CSV copied to clipboard successfully.',
                );
              }
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.trash, size: 18, color: IosColors.systemRed),
                SizedBox(width: 8),
                Text('Clear All Logs'),
              ],
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              _confirmClearLogs();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _confirmClearLogs() {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Clear All Logs?'),
        content: const Text('This will delete all saved SMS transaction logs and history permanently.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Clear'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await TransactionHistoryService.clearLogs();
              await _loadLogsAndStats();
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

  Future<void> _showLogDetails(TransactionLog log) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoPopupSurface(
        child: Container(
          color: IosColors.secondaryBackground,
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: IosColors.quaternaryLabel,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      log.status == TransactionStatus.forwarded
                          ? '₹${log.formattedAmount}'
                          : 'SMS Log',
                      style: TextStyle(
                        color: log.status == TransactionStatus.forwarded
                            ? IosColors.systemGreen
                            : IosColors.label,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: log.status == TransactionStatus.forwarded
                            ? IosColors.systemGreen.withValues(alpha: 0.15)
                            : IosColors.secondaryLabel.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        log.status == TransactionStatus.forwarded ? 'Credited' : 'Filtered',
                        style: TextStyle(
                          color: log.status == TransactionStatus.forwarded
                            ? IosColors.systemGreen
                            : IosColors.secondaryLabel,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailTile(
                  label: 'Sender / UPI',
                  value: log.sender.isNotEmpty ? log.sender : 'Unknown',
                  icon: CupertinoIcons.person_crop_circle_fill,
                ),
                if (log.txnId.isNotEmpty)
                  _buildDetailTile(
                    label: 'Transaction ID / UTR',
                    value: log.txnId,
                    icon: CupertinoIcons.number_circle_fill,
                    canCopy: true,
                  ),
                _buildDetailTile(
                  label: 'Time',
                  value: _formatTimestamp(log.timestamp),
                  icon: CupertinoIcons.clock_fill,
                ),
                _buildDetailTile(
                  label: 'Status Note',
                  value: log.statusReason,
                  icon: CupertinoIcons.info_circle_fill,
                ),
                const SizedBox(height: 12),
                const Text(
                  'RAW SMS TEXT',
                  style: TextStyle(
                    color: IosColors.secondaryLabel,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: IosColors.tertiaryBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    log.rawBody,
                    style: const TextStyle(
                      color: IosColors.label,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (log.status == TransactionStatus.forwarded) ...[
                      Expanded(
                        child: CupertinoButton(
                          color: IosColors.systemPurple,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          borderRadius: BorderRadius.circular(10),
                          onPressed: () {
                            SoundboxService.announcePayment(
                              amount: log.formattedAmount,
                              sender: log.sender,
                              bank: 'Union Bank',
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.speaker_2_fill, size: 16),
                              SizedBox(width: 6),
                              Text('Speak Alert', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: CupertinoButton(
                        color: IosColors.tertiaryBackground,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        borderRadius: BorderRadius.circular(10),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close', style: TextStyle(color: IosColors.label, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTile({
    required String label,
    required String value,
    required IconData icon,
    bool canCopy = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: IosColors.secondaryLabel),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: IosColors.secondaryLabel, fontSize: 13),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: IosColors.label,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (canCopy) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: value));
              },
              child: const Icon(CupertinoIcons.doc_on_doc, size: 14, color: IosColors.systemBlue),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayTotal = (_stats['todayTotal'] is num) ? (_stats['todayTotal'] as num).toDouble() : 0.0;
    final totalAmount = (_stats['totalAmount'] is num) ? (_stats['totalAmount'] as num).toDouble() : 0.0;
    final todayCount = (_stats['todayForwardedCount'] is int) ? (_stats['todayForwardedCount'] as int) : 0;
    final logsList = _filteredLogs;

    return Scaffold(
      backgroundColor: IosColors.systemBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // iOS Large Title Navigation Bar
          CupertinoSliverNavigationBar(
            largeTitle: const Text(
              'History',
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _loadLogsAndStats,
                  child: const Icon(CupertinoIcons.arrow_clockwise, size: 20, color: IosColors.systemBlue),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _showMoreOptions,
                  child: const Icon(CupertinoIcons.ellipsis_circle, size: 22, color: IosColors.systemBlue),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CupertinoActivityIndicator(radius: 14),
              ),
            )
          else ...[
            // Stats Summary Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IosGroupedCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "TODAY'S CREDITS",
                                  style: TextStyle(
                                    color: IosColors.secondaryLabel,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${todayTotal.toStringAsFixed(todayTotal.truncateToDouble() == todayTotal ? 0 : 2)}',
                                  style: const TextStyle(
                                    color: IosColors.systemGreen,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$todayCount payment${todayCount != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    color: IosColors.secondaryLabel,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 42,
                            width: 0.5,
                            color: IosColors.separator,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ALL-TIME TOTAL',
                                    style: TextStyle(
                                      color: IosColors.secondaryLabel,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${totalAmount.toStringAsFixed(totalAmount.truncateToDouble() == totalAmount ? 0 : 2)}',
                                    style: const TextStyle(
                                      color: IosColors.label,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_stats['forwardedCount'] ?? 0} total payments',
                                    style: const TextStyle(
                                      color: IosColors.secondaryLabel,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // iOS Segmented Control
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: CupertinoSlidingSegmentedControl<int>(
                          backgroundColor: IosColors.secondaryBackground,
                          thumbColor: IosColors.tertiaryBackground,
                          groupValue: _selectedSegment,
                          children: const {
                            0: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              child: Text('All Logs', style: TextStyle(fontSize: 13, color: IosColors.label)),
                            ),
                            1: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              child: Text('Credited', style: TextStyle(fontSize: 13, color: IosColors.systemGreen)),
                            ),
                            2: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              child: Text('Filtered', style: TextStyle(fontSize: 13, color: IosColors.secondaryLabel)),
                            ),
                          },
                          onValueChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSegment = val);
                            }
                          },
                        ),
                      ),
                    ),

                    // iOS Search Text Field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      child: CupertinoSearchTextField(
                        controller: _searchController,
                        placeholder: 'Search amount, sender, UTR...',
                        style: const TextStyle(color: IosColors.label, fontSize: 14),
                        placeholderStyle: const TextStyle(color: IosColors.secondaryLabel, fontSize: 14),
                        backgroundColor: IosColors.secondaryBackground,
                        borderRadius: BorderRadius.circular(10),
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),

            // Transaction Logs List
            if (logsList.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.doc_text_search,
                        size: 48,
                        color: IosColors.tertiaryLabel.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No Transactions Found',
                        style: TextStyle(
                          color: IosColors.secondaryLabel,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Incoming Union Bank SMS logs will appear here.',
                        style: TextStyle(
                          color: IosColors.tertiaryLabel,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final log = logsList[index];
                      final isCredited = log.status == TransactionStatus.forwarded;

                      return IosGroupedCard(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        onTap: () => _showLogDetails(log),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isCredited
                                    ? IosColors.systemGreen.withValues(alpha: 0.15)
                                    : IosColors.tertiaryBackground,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCredited
                                    ? CupertinoIcons.money_dollar
                                    : CupertinoIcons.chat_bubble_text,
                                color: isCredited ? IosColors.systemGreen : IosColors.secondaryLabel,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          isCredited
                                              ? (log.sender.isNotEmpty ? log.sender : 'Union Bank Credit')
                                              : (log.sender.isNotEmpty ? log.sender : 'SMS Message'),
                                          style: const TextStyle(
                                            color: IosColors.label,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        isCredited ? '+₹${log.formattedAmount}' : 'Filtered',
                                        style: TextStyle(
                                          color: isCredited ? IosColors.systemGreen : IosColors.secondaryLabel,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        _formatTimestamp(log.timestamp),
                                        style: const TextStyle(
                                          color: IosColors.secondaryLabel,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (log.txnId.isNotEmpty) ...[
                                        const Text(' • ', style: TextStyle(color: IosColors.tertiaryLabel)),
                                        Expanded(
                                          child: Text(
                                            'Ref: ${log.txnId}',
                                            style: const TextStyle(
                                              color: IosColors.secondaryLabel,
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              CupertinoIcons.chevron_right,
                              color: IosColors.tertiaryLabel,
                              size: 14,
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: logsList.length,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
