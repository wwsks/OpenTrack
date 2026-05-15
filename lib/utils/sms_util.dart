import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import '../models/sms_model.dart';

class SmsUtil {
  static Future<List<SmsModel>> readSmsByTimeFilter(int daysFilter) async {
    final query = SmsQuery();

    final messages = await query.querySms(
      kinds: [SmsQueryKind.inbox],
    );

    List<SmsModel> result = messages
        .map((m) => SmsModel(
              id: (m.id ?? 0).toString(),
              body: m.body ?? '',
              timestamp: m.date?.millisecondsSinceEpoch ?? 0,
            ))
        .toList();

    if (daysFilter > 0) {
      final now = DateTime.now();
      final cutoff = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: daysFilter - 1))
          .millisecondsSinceEpoch;
      result = result.where((sms) => sms.timestamp >= cutoff).toList();
    }

    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }

  static String formatPickupCode(String code) {
    return code.split(',').map((singleCode) {
      final trimmed = singleCode.trim();
      if (trimmed.contains('-')) return trimmed;
      final digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');
      if (digitsOnly.length >= 8) {
        return digitsOnly.replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)} ').trim();
      }
      return digitsOnly;
    }).join(', ');
  }

  static bool isSameDay(int ts1, int ts2) {
    final d1 = DateTime.fromMillisecondsSinceEpoch(ts1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(ts2);
    return d1.year == d2.year && d1.day == d2.day;
  }
}
