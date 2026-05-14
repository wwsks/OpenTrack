class TrackingInfo {
  final String companyCode;
  final String trackingNumber;
  final String state;
  final String ischeck;
  final String message;
  final List<TrackingEvent> data;

  TrackingInfo({
    required this.companyCode,
    required this.trackingNumber,
    required this.state,
    required this.ischeck,
    required this.message,
    required this.data,
  });

  factory TrackingInfo.fromJson(Map<String, dynamic> json) {
    return TrackingInfo(
      companyCode: json['com'] ?? '',
      trackingNumber: json['nu'] ?? '',
      state: json['state'] ?? '',
      ischeck: json['ischeck'] ?? '0',
      message: json['message'] ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => TrackingEvent.fromJson(e))
              .toList() ??
          [],
    );
  }

  /// 是否已签收
  /// 优先判断 ischeck，其次判断 state
  bool get isSigned => ischeck == '1' || state == '3';
}

class TrackingEvent {
  final String context;
  final String time;
  final String ftime;
  final String? status;
  final String? statusCode;
  final String? location;

  TrackingEvent({
    required this.context,
    required this.time,
    required this.ftime,
    this.status,
    this.statusCode,
    this.location,
  });

  factory TrackingEvent.fromJson(Map<String, dynamic> json) {
    return TrackingEvent(
      context: json['context'] ?? '',
      time: json['time'] ?? '',
      ftime: json['ftime'] ?? '',
      status: json['status'],
      statusCode: json['statusCode'],
      location: json['location'],
    );
  }
}
