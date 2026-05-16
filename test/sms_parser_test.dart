import 'package:flutter_test/flutter_test.dart';
import 'package:opentrack/utils/sms_parser.dart';

void main() {
  final parser = SmsParser();

  test('极兔速递 - 请凭取件码', () {
    const sms = '【极兔速递】请凭3-2-5031到长春理工南区菜鸟驿站取运单尾号2081包裹';
    final result = parser.parseSms(sms);
    expect(result.success, true);
    expect(result.code, '3-2-5031');
    expect(result.address, '长春理工南区菜鸟驿站');
    expect(result.sender, '极兔速递');
  });

  test('京东快递 - 取件码', () {
    const sms = '【京东快递】取件码J-2-5216，您的快件尾号1494已送达长春理工大学南校区服务站，地址：吉林长春市朝阳区长春理工大学南校区，取件和寄件可咨询 3.cn/-2O64NfS';
    final result = parser.parseSms(sms);
    expect(result.success, true);
    expect(result.code, 'J-2-5216');
    expect(result.address, '吉林长春市朝阳区长春理工大学南校区');
    expect(result.sender, '京东快递');
  });

  test('圆通速递 - 请凭取件码', () {
    const sms = '【圆通速递】请凭4-2-4077到长春理工南区菜鸟驿站取件，地址：校园快递服务中心（南研楼一楼）。';
    final result = parser.parseSms(sms);
    expect(result.success, true);
    expect(result.code, '4-2-4077');
    expect(result.sender, '圆通速递');
  });

  test('圆通快递 - 请凭取件码', () {
    const sms = '【圆通快递】请凭4-6-3017到长春理工南区菜鸟驿站取运单尾号6799包裹';
    final result = parser.parseSms(sms);
    expect(result.success, true);
    expect(result.code, '4-6-3017');
    expect(result.address, '长春理工南区菜鸟驿站');
    expect(result.sender, '圆通速递');
  });

  test('非取件码短信不应匹配', () {
    const sms = '【京东快递】您的快递已送达，签收人：张三，如有问题请联系快递员';
    final result = parser.parseSms(sms);
    expect(result.success, false);
  });
}
