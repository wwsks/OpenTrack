import 'sms_model.dart';

class SmsData {
  final String address;
  final String code;
  final SmsModel sms;
  final String id;
  bool isCompleted;
  final String lockerNumber;

  /// 是否由 LLM 从正则解析失败的短信中兜底提取
  final bool extractedByLlm;

  SmsData({
    required this.address,
    required this.code,
    required this.sms,
    required this.id,
    this.isCompleted = false,
    this.lockerNumber = '',
    this.extractedByLlm = false,
  });
}
