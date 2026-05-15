import 'sms_data.dart';

class ParcelData {
  final String address;
  final List<SmsData> smsDataList;
  int num;

  ParcelData({required this.address, required this.smsDataList, this.num = 0});
}
