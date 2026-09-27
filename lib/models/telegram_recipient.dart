import 'dart:convert';

class TelegramRecipient {
  final String id;
  final String name;
  final String chatId;
  final bool isEnabled;

  const TelegramRecipient({
    required this.id,
    required this.name,
    required this.chatId,
    this.isEnabled = true,
  });

  bool get isActive => isEnabled;

  TelegramRecipient copyWith({
    String? id,
    String? name,
    String? chatId,
    bool? isEnabled,
    bool? isActive,
  }) {
    return TelegramRecipient(
      id: id ?? this.id,
      name: name ?? this.name,
      chatId: chatId ?? this.chatId,
      isEnabled: isEnabled ?? (isActive ?? this.isEnabled),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'chatId': chatId,
      'isEnabled': isEnabled,
    };
  }

  factory TelegramRecipient.fromMap(Map<String, dynamic> map) {
    return TelegramRecipient(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: map['name']?.toString() ?? 'Agent',
      chatId: map['chatId']?.toString() ?? '',
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory TelegramRecipient.fromJson(String source) =>
      TelegramRecipient.fromMap(json.decode(source) as Map<String, dynamic>);
}
