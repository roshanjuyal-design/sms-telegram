import 'dart:convert';

enum QueueStatus {
  pending,
  retrying,
  sent,
  failed,
}

class QueuedMessage {
  final String id;
  final String rawSms;
  final String formattedTelegramMessage;
  final String sender;
  final String amount;
  final String txnId;
  final List<String> targetChatIds;
  final List<String> deliveredChatIds;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final int retryCount;
  final String? lastError;
  final QueueStatus status;

  const QueuedMessage({
    required this.id,
    required this.rawSms,
    required this.formattedTelegramMessage,
    required this.sender,
    required this.amount,
    required this.txnId,
    required this.targetChatIds,
    this.deliveredChatIds = const [],
    required this.createdAt,
    this.lastAttemptAt,
    this.retryCount = 0,
    this.lastError,
    this.status = QueueStatus.pending,
  });

  bool get isFullyDelivered =>
      targetChatIds.isNotEmpty &&
      targetChatIds.every((id) => deliveredChatIds.contains(id));

  List<String> get pendingChatIds =>
      targetChatIds.where((id) => !deliveredChatIds.contains(id)).toList();

  QueuedMessage copyWith({
    String? id,
    String? rawSms,
    String? formattedTelegramMessage,
    String? sender,
    String? amount,
    String? txnId,
    List<String>? targetChatIds,
    List<String>? deliveredChatIds,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    int? retryCount,
    String? lastError,
    QueueStatus? status,
  }) {
    return QueuedMessage(
      id: id ?? this.id,
      rawSms: rawSms ?? this.rawSms,
      formattedTelegramMessage:
          formattedTelegramMessage ?? this.formattedTelegramMessage,
      sender: sender ?? this.sender,
      amount: amount ?? this.amount,
      txnId: txnId ?? this.txnId,
      targetChatIds: targetChatIds ?? this.targetChatIds,
      deliveredChatIds: deliveredChatIds ?? this.deliveredChatIds,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rawSms': rawSms,
      'formattedTelegramMessage': formattedTelegramMessage,
      'sender': sender,
      'amount': amount,
      'txnId': txnId,
      'targetChatIds': targetChatIds,
      'deliveredChatIds': deliveredChatIds,
      'createdAt': createdAt.toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'retryCount': retryCount,
      'lastError': lastError,
      'status': status.name,
    };
  }

  factory QueuedMessage.fromMap(Map<String, dynamic> map) {
    return QueuedMessage(
      id: map['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      rawSms: map['rawSms']?.toString() ?? '',
      formattedTelegramMessage:
          map['formattedTelegramMessage']?.toString() ?? '',
      sender: map['sender']?.toString() ?? '',
      amount: map['amount']?.toString() ?? '',
      txnId: map['txnId']?.toString() ?? '',
      targetChatIds: (map['targetChatIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      deliveredChatIds: (map['deliveredChatIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastAttemptAt: map['lastAttemptAt'] != null
          ? DateTime.tryParse(map['lastAttemptAt'].toString())
          : null,
      retryCount: map['retryCount'] is int ? map['retryCount'] as int : 0,
      lastError: map['lastError']?.toString(),
      status: QueueStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => QueueStatus.pending,
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory QueuedMessage.fromJson(String source) =>
      QueuedMessage.fromMap(json.decode(source) as Map<String, dynamic>);
}
