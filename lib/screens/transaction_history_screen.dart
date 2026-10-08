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
  int _selectedDateFilter = 0; // 0: Today, 1: Yesterday, 2: Pick Date, 3: All Time
  DateTime? _customSelectedDate;
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
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    return _allLogs.where((log) {
      // 1. Date Filter
      if (_selectedDateFilter == 0) {
        // Today
        final isToday = log.timestamp.year == now.year &&
            log.timestamp.month == now.month &&
            log.timestamp.day == now.day;
        if (!isToday) return false;
      } else if (_selectedDateFilter == 1) {
        // Yesterday
        final isYesterday = log.timestamp.year == yesterday.year &&
            log.timestamp.month == yesterday.month &&
            log.timestamp.day == yesterday.day;
        if (!isYesterday) return false;
      } else if (_selectedDateFilter == 2) {
        // Custom Selected Date
        if (_customSelectedDate != null) {
          final isSameDay = log.timestamp.year == _customSelectedDate!.year &&
              log.timestamp.month == _customSelectedDate!.month &&
              log.timestamp.day == _customSelectedDate!.day;
          if (!isSameDay) return false;
        }
      }
      // If _selectedDateFilter == 3, All Time (no date restriction)

      // 2. Segment Filter
      if (_selectedSegment == 1 && log.status != TransactionStatus.forwarded) {
        return false;
      }
      if (_selectedSegment == 2 && log.status != TransactionStatus.filtered) {
        return false;
      }

      // 3. Search Query
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
    final yesterday = now.subtract(const Duration(days: 1));
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    if (isToday) {
      return 'Today, $hour:$minute';
    } else if (isYesterday) {
      return 'Yesterday, $hour:$minute';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $hour:$minute';
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  String _formatCompactCurrency(double amount) {
    if (amount == amount.truncateToDouble()) {
      final whole = amount.toInt().toString();
      if (whole.length > 3) {
        final lastThree = whole.substring(whole.length - 3);
        final remaining = whole.substring(0, whole.length - 3);
        final reg = RegExp(r'(\d+?)(?=(\d{2})+(?!\d))');
        final formattedRemaining = remaining.replaceAllMapped(reg, (Match m) => '${m[1]},');
        return '$formattedRemaining,$lastThree';
      }
      return whole;
    }
    return TransactionHistoryService.formatCurrency(amount);
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    DateTime tempDate = _customSelectedDate ?? now;
    if (tempDate.isAfter(now)) {
      tempDate = now;
    }
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 310,
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
                    const Text(
                      'Select History Date',
                      style: TextStyle(color: IosColors.label, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('Done', style: TextStyle(color: IosColors.systemBlue, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {
                          _customSelectedDate = tempDate;
                          _selectedDateFilter = 2;
                        });
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: tempDate,
                  maximumDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
                  minimumDate: DateTime(2025, 1, 1),
                  onDateTimeChanged: (newDt) {
                    tempDate = newDt;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterChip({
    required int index,
    required String label,
    required IconData icon,
    VoidCallback? onTapCustom,
  }) {
    final isSelected = _selectedDateFilter == index;
    return GestureDetector(
      onTap: onTapCustom ??
          () {
            setState(() {
              _selectedDateFilter = index;
            });
          },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? IosColors.systemBlue : IosColors.secondaryBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? IosColors.systemBlue : IosColors.separator,
            width: 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: IosColors.systemBlue.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : IosColors.secondaryLabel,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : IosColors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMoreOptions() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('UPI Merchant Statement & Exports'),
        message: const Text('View merchant statement table or export clean transaction logs.'),
        actions: [
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.table, size: 18, color: IosColors.systemOrange),
                SizedBox(width: 8),
                Text('View Merchant Statement (Table)'),
              ],
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _showMerchantStatementTableDialog();
            },
          ),
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.doc_text, size: 18, color: IosColors.systemBlue),
                SizedBox(width: 8),
                Text('Copy Clean Statement (WhatsApp / Notes)'),
              ],
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final text = await TransactionHistoryService.exportCleanStatementText(
                creditedOnly: _selectedSegment == 1,
                customLogs: _filteredLogs,
              );
              await Clipboard.setData(ClipboardData(text: text));
              if (mounted) {
                _showIosAlert(
                  title: 'Statement Copied! 📋',
                  message: 'Clean merchant statement formatted and copied to clipboard. You can paste it into WhatsApp, Notes, or Email.',
                );
              }
            },
          ),
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.square_grid_2x2, size: 18, color: IosColors.systemGreen),
                SizedBox(width: 8),
                Text('Copy for Excel / Google Sheets'),
              ],
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final tsv = await TransactionHistoryService.exportExcelTable(
                creditedOnly: _selectedSegment == 1,
                customLogs: _filteredLogs,
              );
              await Clipboard.setData(ClipboardData(text: tsv));
              if (mounted) {
                _showIosAlert(
                  title: 'Excel Table Copied! 📊',
                  message: 'Tab-delimited table copied to clipboard. Paste directly into Google Sheets or Microsoft Excel to get organized columns.',
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

  void _showMerchantStatementTableDialog() {
    final List<TransactionLog> statementLogs = _filteredLogs;
    final double totalNet = statementLogs
        .where((l) => l.status == TransactionStatus.forwarded)
        .fold(0.0, (sum, l) => sum + l.amount);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

              // Title Header matching Screenshot 2
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'UPI Transactions Merchant Statement',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Statement Date: ${TransactionHistoryService.formatTxnDate(DateTime.now(), withTime: false)} | ${statementLogs.length} Entries',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white38),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white12, height: 1),

              // Scrollable Table exactly matching Screenshot 2
              Expanded(
                child: statementLogs.isEmpty
                    ? const Center(
                        child: Text(
                          'No transaction logs found',
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      )
                    : Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Table Header matching Screenshot 2 (Gold/Yellow banner)
                                Container(
                                  color: const Color(0xFFFFC107),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      _buildTableCell('TXN DT', width: 105, isHeader: true),
                                      _buildTableCell('PAYER', width: 145, isHeader: true),
                                      _buildTableCell('RRN', width: 120, isHeader: true),
                                      _buildTableCell('TXN AMT', width: 95, isHeader: true, alignRight: true),
                                      _buildTableCell('MDR', width: 55, isHeader: true, alignRight: true),
                                      _buildTableCell('GST', width: 55, isHeader: true, alignRight: true),
                                      _buildTableCell('NET AMT', width: 95, isHeader: true, alignRight: true),
                                      _buildTableCell('REMARKS', width: 155, isHeader: true),
                                    ],
                                  ),
                                ),

                                // Table Rows
                                ...statementLogs.asMap().entries.map((entry) {
                                  final int index = entry.key;
                                  final TransactionLog log = entry.value;
                                  final Color rowColor = index.isEven
                                      ? const Color(0xFF242426)
                                      : const Color(0xFF1E1E20);

                                  final String txnDt = TransactionHistoryService.formatTxnDate(log.timestamp);
                                  final String payer = log.sender.isNotEmpty ? log.sender : 'Unknown';
                                  final String rrn = log.txnId.isNotEmpty ? log.txnId : '-';
                                  final String amt = TransactionHistoryService.formatCurrency(log.amount);
                                  final String remarks = log.status == TransactionStatus.forwarded
                                      ? 'Payment from UPI'
                                      : log.statusReason;

                                  return Container(
                                    color: rowColor,
                                    padding: const EdgeInsets.symmetric(vertical: 7),
                                    child: Row(
                                      children: [
                                        _buildTableCell(txnDt, width: 105),
                                        _buildTableCell(payer, width: 145),
                                        _buildTableCell(rrn, width: 120),
                                        _buildTableCell(amt, width: 95, alignRight: true),
                                        _buildTableCell('0.00', width: 55, alignRight: true),
                                        _buildTableCell('0.00', width: 55, alignRight: true),
                                        _buildTableCell(amt, width: 95, alignRight: true),
                                        _buildTableCell(remarks, width: 155),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),

              const Divider(color: Colors.white12, height: 1),

              // Bottom Total & Action Bar
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF18181A),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL NET AMOUNT:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '₹${TransactionHistoryService.formatCurrency(totalNet)}',
                          style: const TextStyle(
                            color: Color(0xFF4ADE80),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC107),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(CupertinoIcons.square_grid_2x2, size: 16),
                            label: const Text(
                              'Copy for Excel',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: () async {
                              final tsv = await TransactionHistoryService.exportExcelTable(
                                customLogs: statementLogs,
                              );
                              await Clipboard.setData(ClipboardData(text: tsv));
                              if (context.mounted) {
                                Navigator.of(ctx).pop();
                                _showIosAlert(
                                  title: 'Excel Table Copied! 📊',
                                  message: 'Paste directly into Google Sheets or Excel to get columns matching this table.',
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(CupertinoIcons.doc_text, size: 16),
                            label: const Text(
                              'Copy Text',
                              style: TextStyle(fontSize: 13),
                            ),
                            onPressed: () async {
                              final text = await TransactionHistoryService.exportCleanStatementText(
                                customLogs: statementLogs,
                              );
                              await Clipboard.setData(ClipboardData(text: text));
                              if (context.mounted) {
                                Navigator.of(ctx).pop();
                                _showIosAlert(
                                  title: 'Statement Copied! 📋',
                                  message: 'Clean text statement copied to clipboard for WhatsApp/Email.',
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    required double width,
    bool isHeader = false,
    bool alignRight = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          color: isHeader ? Colors.black : Colors.white.withValues(alpha: 0.9),
          fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
          fontSize: isHeader ? 11 : 12,
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
    final todayCount = (_stats['todayForwardedCount'] is int) ? (_stats['todayForwardedCount'] as int) : 0;
    final allTimeTotal = (_stats['allTimeTotal'] is num)
        ? (_stats['allTimeTotal'] as num).toDouble()
        : ((_stats['totalAmount'] is num) ? (_stats['totalAmount'] as num).toDouble() : 0.0);
    final allTimeCount = (_stats['totalForwarded'] is int)
        ? (_stats['totalForwarded'] as int)
        : ((_stats['forwardedCount'] is int) ? (_stats['forwardedCount'] as int) : 0);

    String card1Title = "TODAY'S CREDITS";
    double card1Amount = todayTotal;
    int card1Count = todayCount;

    if (_selectedDateFilter == 1) {
      card1Title = "YESTERDAY'S CREDITS";
      card1Amount = (_stats['yesterdayTotal'] is num) ? (_stats['yesterdayTotal'] as num).toDouble() : 0.0;
      card1Count = (_stats['yesterdayForwardedCount'] is int) ? (_stats['yesterdayForwardedCount'] as int) : 0;
    } else if (_selectedDateFilter == 2) {
      if (_customSelectedDate != null) {
        final dayStr = _customSelectedDate!.day.toString().padLeft(2, '0');
        final monthStr = _getMonthAbbr(_customSelectedDate!.month).toUpperCase();
        card1Title = '$dayStr $monthStr CREDITS';
        final dayLogs = _allLogs.where((l) =>
            l.timestamp.year == _customSelectedDate!.year &&
            l.timestamp.month == _customSelectedDate!.month &&
            l.timestamp.day == _customSelectedDate!.day &&
            l.status == TransactionStatus.forwarded).toList();
        card1Amount = dayLogs.fold(0.0, (sum, l) => sum + l.amount);
        card1Count = dayLogs.length;
      } else {
        card1Title = 'SELECTED DATE';
        card1Amount = 0.0;
        card1Count = 0;
      }
    } else if (_selectedDateFilter == 3) {
      card1Title = 'TOTAL CREDITS';
      card1Amount = allTimeTotal;
      card1Count = allTimeCount;
    }

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
                                Text(
                                  card1Title,
                                  style: const TextStyle(
                                    color: IosColors.secondaryLabel,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${_formatCompactCurrency(card1Amount)}',
                                  style: const TextStyle(
                                    color: IosColors.systemGreen,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$card1Count payment${card1Count != 1 ? 's' : ''}',
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
                                    '₹${_formatCompactCurrency(allTimeTotal)}',
                                    style: const TextStyle(
                                      color: IosColors.label,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$allTimeCount total payment${allTimeCount != 1 ? 's' : ''}',
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

                    // Date Filter Chips (Today, Yesterday, Pick Date, All Time)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 2),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildDateFilterChip(
                              index: 0,
                              label: 'Today',
                              icon: CupertinoIcons.sun_max_fill,
                            ),
                            const SizedBox(width: 8),
                            _buildDateFilterChip(
                              index: 1,
                              label: 'Yesterday',
                              icon: CupertinoIcons.arrow_counterclockwise,
                            ),
                            const SizedBox(width: 8),
                            _buildDateFilterChip(
                              index: 2,
                              label: _customSelectedDate != null
                                  ? '${_customSelectedDate!.day.toString().padLeft(2, '0')} ${_getMonthAbbr(_customSelectedDate!.month)}'
                                  : 'Pick Date',
                              icon: CupertinoIcons.calendar,
                              onTapCustom: () {
                                if (_selectedDateFilter == 2 && _customSelectedDate != null) {
                                  _pickCustomDate();
                                } else if (_customSelectedDate != null) {
                                  setState(() => _selectedDateFilter = 2);
                                } else {
                                  _pickCustomDate();
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildDateFilterChip(
                              index: 3,
                              label: 'All Time',
                              icon: CupertinoIcons.time,
                            ),
                          ],
                        ),
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
                      Text(
                        _selectedDateFilter == 0
                            ? 'No transactions recorded today yet.'
                            : _selectedDateFilter == 1
                                ? 'No transactions recorded yesterday.'
                                : _selectedDateFilter == 2
                                    ? 'No transactions on selected date.'
                                    : 'Incoming Union Bank SMS logs will appear here.',
                        style: const TextStyle(
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
