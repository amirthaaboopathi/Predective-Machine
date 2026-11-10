enum ChatMessageStatus {
  sending,
  sent,
  error,
}

/// Represents a single message exchange in the appliance AI chat conversation.
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final ChatMessageStatus status;
  final String? referencedApplianceId;
  final String? referencedApplianceName;
  final List<String>? suggestedActions;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.status = ChatMessageStatus.sent,
    this.referencedApplianceId,
    this.referencedApplianceName,
    this.suggestedActions,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    ChatMessageStatus? status,
    String? referencedApplianceId,
    String? referencedApplianceName,
    List<String>? suggestedActions,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      referencedApplianceId: referencedApplianceId ?? this.referencedApplianceId,
      referencedApplianceName:
          referencedApplianceName ?? this.referencedApplianceName,
      suggestedActions: suggestedActions ?? this.suggestedActions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'referencedApplianceId': referencedApplianceId,
      'referencedApplianceName': referencedApplianceName,
      'suggestedActions': suggestedActions,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      isUser: map['isUser'] == true,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: ChatMessageStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ChatMessageStatus.sent,
      ),
      referencedApplianceId: map['referencedApplianceId']?.toString(),
      referencedApplianceName: map['referencedApplianceName']?.toString(),
      suggestedActions: map['suggestedActions'] != null
          ? List<String>.from(map['suggestedActions'] as List)
          : null,
    );
  }
}
