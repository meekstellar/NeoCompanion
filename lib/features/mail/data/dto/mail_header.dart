/// Header row from `/characters/{id}/mail/` — the inbox list shape.
class MailHeader {
  const MailHeader({
    required this.mailId,
    required this.fromId,
    required this.subject,
    required this.timestamp,
    required this.isRead,
    required this.recipients,
    required this.labels,
  });

  final int mailId;
  final int fromId;
  final String subject;
  final DateTime timestamp;
  final bool isRead;
  final List<MailRecipient> recipients;
  final List<int> labels;

  factory MailHeader.fromJson(Map<String, dynamic> json) {
    return MailHeader(
      mailId: (json['mail_id'] as num).toInt(),
      fromId: (json['from'] as num?)?.toInt() ?? 0,
      subject: json['subject'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['is_read'] as bool? ?? false,
      recipients: (json['recipients'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(MailRecipient.fromJson)
          .toList(),
      labels: (json['labels'] as List<dynamic>? ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }
}

class MailRecipient {
  const MailRecipient({required this.id, required this.type});
  final int id;
  final String type;

  factory MailRecipient.fromJson(Map<String, dynamic> json) {
    return MailRecipient(
      id: (json['recipient_id'] as num).toInt(),
      type: json['recipient_type'] as String? ?? 'character',
    );
  }
}

/// Full body returned by `/characters/{id}/mail/{mail_id}/`. The body
/// is HTML — the screen renders it stripped to plain text.
class MailBody {
  const MailBody({
    required this.subject,
    required this.fromId,
    required this.timestamp,
    required this.body,
  });

  final String subject;
  final int fromId;
  final DateTime timestamp;
  final String body;

  factory MailBody.fromJson(Map<String, dynamic> json) {
    return MailBody(
      subject: json['subject'] as String? ?? '',
      fromId: (json['from'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.parse(json['timestamp'] as String),
      body: json['body'] as String? ?? '',
    );
  }
}
