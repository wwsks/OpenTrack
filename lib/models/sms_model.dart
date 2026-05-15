class SmsModel {
  final String id;
  final String body;
  final int timestamp;

  SmsModel({required this.id, required this.body, required this.timestamp});

  Map<String, dynamic> toJson() => {'id': id, 'body': body, 'timestamp': timestamp};
  factory SmsModel.fromJson(Map<String, dynamic> json) =>
      SmsModel(id: json['id'], body: json['body'], timestamp: json['timestamp']);
}
