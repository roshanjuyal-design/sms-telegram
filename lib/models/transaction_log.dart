import 'dart:convert';

enum TransactionStatus {
  forwarded,
  filtered,
  failed,
}

class TransactionLog {
  final String id;
  final String sender;
  final String rawBody;
  final double amount;
  final String formattedAmount;
  final String txnId;
  final String bank;
  final TransactionStatus status;
  final String statusReason;
  final DateTime timestamp;
  final bool isCredit;

  const TransactionLog({
    required this.id,
    required this.sender,
    required this.rawBody,
    required this.amount,
    required this.formattedAmount,
    required this.txnId,
    required this.bank,
    required this.status,
    required this.statusReason,
    required this.timestamp,
    this.isCredit = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'rawBody': rawBody,
      'amount': amount,
      'formattedAmount': formattedAmount,
      'txnId': txnId,
      'bank': bank,
      'status': status.name,
      'statusReason': statusReason,
      'timestamp': timestamp.toIso8601String(),
      'isCredit': isCredit,
    };
  }

  factory TransactionLog.fromMap(Map<String, dynamic> map) {
    return TransactionLog(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      sender: map['sender']?.toString() ?? 'Unknown',
      rawBody: map['rawBody']?.toString() ?? '',
      amount: (map['amount'] is num) ? (map['amount'] as num).toDouble() : 0.0,
      formattedAmount: map['formattedAmount']?.toString() ?? '0',
      txnId: map['txnId']?.toString() ?? '',
      bank: map['bank']?.toString() ?? 'Union Bank',
      status: _statusFromString(map['status']?.toString()),
      statusReason: map['statusReason']?.toString() ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isCredit: map['isCredit'] as bool? ?? true,
    );
  }

  static TransactionStatus _statusFromString(String? str) {
    switch (str) {
      case 'filtered':
        return TransactionStatus.filtered;
      case 'failed':
        return TransactionStatus.failed;
      default:
        return TransactionStatus.forwarded;
    }
  }

  String toJson() => json.encode(toMap());

  factory TransactionLog.fromJson(String source) =>
      TransactionLog.fromMap(json.decode(source) as Map<String, dynamic>);
}
