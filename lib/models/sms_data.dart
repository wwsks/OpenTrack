import 'sms_model.dart';

class SmsData {
  final String address;
  final String code;
  final SmsModel sms;
  final String id;
  bool isCompleted;
  final String lockerNumber;

  SmsData({
    required this.address,
    required this.code,
    required this.sms,
    required this.id,
    this.isCompleted = false,
    this.lockerNumber = '',
  });
}
