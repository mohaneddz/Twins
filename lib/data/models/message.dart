class TwinsMessage {
  final String id;
  final String spaceId;
  final String chatId;
  final String authorId;
  final String body;
  final String? replyToId;
  final String? attachedItemId;
  final String? attachedEventId;
  final DateTime createdAt;

  const TwinsMessage({
    required this.id,
    required this.spaceId,
    required this.chatId,
    required this.authorId,
    required this.body,
    this.replyToId,
    this.attachedItemId,
    this.attachedEventId,
    required this.createdAt,
  });

  factory TwinsMessage.fromJson(Map<String, dynamic> json) => TwinsMessage(
        id: json['id'] as String,
        spaceId: json['space_id'] as String,
        chatId: json['chat_id'] as String,
        authorId: json['author_id'] as String,
        body: json['body'] as String,
        replyToId: json['reply_to_id'] as String?,
        attachedItemId: json['attached_item_id'] as String?,
        attachedEventId: json['attached_event_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'space_id': spaceId,
        'chat_id': chatId,
        'body': body,
        'reply_to_id': replyToId,
        'attached_item_id': attachedItemId,
        'attached_event_id': attachedEventId,
      };
}
