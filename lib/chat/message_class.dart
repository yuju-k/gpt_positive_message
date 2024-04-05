class Message {
  final String senderName; //보낸사람
  final String senderUID; //보낸사람 UID
  final String originalMessageContent; //원본 메시지
  final String convertMessageContent; //변경된 메시지
  final String timestamp; //타임스탬프
  final bool isConvertMessage; //변환된 메시지 인지 여부
  final String sentiment; //말투 분석 결과

  Message({
    required this.senderName,
    required this.senderUID,
    required this.originalMessageContent,
    required this.convertMessageContent,
    required this.timestamp,
    required this.isConvertMessage,
    required this.sentiment,
  });

  factory Message.fromMap(Map<dynamic, dynamic> map) {
    return Message(
      senderName: map['senderName'] as String,
      senderUID: map['senderUID'] as String,
      originalMessageContent: map['originalMessageContent'] as String,
      convertMessageContent: map['convertMessageContent'] as String,
      timestamp: map['timestamp'] as String,
      isConvertMessage: map['isConvertMessage'] as bool,
      sentiment: map['sentiment'] as String,
    );
  }
}

List<Message> messages = [];
