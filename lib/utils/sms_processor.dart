import 'package:shared_preferences/shared_preferences.dart';
import '../models/sms_model.dart';
import '../models/sms_data.dart';
import '../models/parcel_data.dart';
import 'sms_parser.dart';
import 'sms_util.dart';

class ProcessResult {
  final List<SmsData> successful;
  final List<ParcelData> parcels;
  final List<SmsModel> failed;

  ProcessResult(this.successful, this.parcels, this.failed);
}

class SmsProcessor {
  static Future<void> loadCustomRulesToParser(SmsParser parser) async {
    final prefs = await SharedPreferences.getInstance();

    final addressPatterns = prefs.getStringList('custom_address_patterns') ?? [];
    for (final p in addressPatterns) {
      if (p.trim().isNotEmpty) parser.addCustomAddressPattern(p);
    }

    final codePatterns = prefs.getStringList('custom_code_patterns') ?? [];
    for (final p in codePatterns) {
      if (p.trim().isNotEmpty) parser.addCustomCodePattern(p);
    }

    final ignoreKeywords = prefs.getStringList('ignore_keywords') ?? [];
    for (final k in ignoreKeywords) {
      if (k.trim().isNotEmpty) parser.addIgnoreKeyword(k);
    }
  }

  static Future<ProcessResult> loadAndProcess({
    required SmsParser parser,
    required List<String> completedIds,
  }) async {
    await loadCustomRulesToParser(parser);
    final systemSms = await SmsUtil.readSmsByTimeFilter(7);
    return process(systemSms, parser, completedIds);
  }

  static ProcessResult process(
    List<SmsModel> messages,
    SmsParser parser,
    List<String> completedIds,
  ) {
    final successful = <SmsData>[];
    final parcelsMap = <String, ParcelData>{};
    final failed = <SmsModel>[];

    for (final sms in messages) {
      final result = parser.parseSms(sms.body);

      if (result.success && result.code.isNotEmpty) {
        final combinedKey = '${sms.id}_${sms.timestamp}';
        final address = result.address.isNotEmpty ? result.address : '未知地址';

        final smsData = SmsData(
          address: address,
          code: result.code,
          sms: sms,
          id: combinedKey,
          lockerNumber: result.lockerNumber,
        );
        successful.add(smsData);

        final existingParcel = parcelsMap[address];
        if (existingParcel != null) {
          final isDuplicate = existingParcel.smsDataList.any((existing) =>
              existing.code == smsData.code &&
              SmsUtil.isSameDay(existing.sms.timestamp, smsData.sms.timestamp));
          if (!isDuplicate) {
            existingParcel.smsDataList.add(smsData);
          }
        } else {
          parcelsMap[address] = ParcelData(
            address: address,
            smsDataList: [smsData],
          );
        }
      } else {
        failed.add(sms);
      }
    }

    successful.sort((a, b) => b.sms.timestamp.compareTo(a.sms.timestamp));
    failed.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    for (final parcel in parcelsMap.values) {
      parcel.smsDataList.sort((a, b) {
        if (a.lockerNumber.isEmpty && b.lockerNumber.isNotEmpty) return 1;
        if (a.lockerNumber.isNotEmpty && b.lockerNumber.isEmpty) return -1;
        final aNum = int.tryParse(a.lockerNumber) ?? 999999;
        final bNum = int.tryParse(b.lockerNumber) ?? 999999;
        if (aNum != bNum) return aNum.compareTo(bNum);
        return b.sms.timestamp.compareTo(a.sms.timestamp);
      });
    }

    final completedIdsSet = completedIds.toSet();
    final parcels = parcelsMap.values.map((parcel) {
      final newList = parcel.smsDataList.map((smsData) {
        final combinedKey = '${smsData.sms.id}_${smsData.sms.timestamp}';
        final isCompleted =
            completedIdsSet.contains(combinedKey) || completedIdsSet.contains(smsData.sms.id);
        return SmsData(
          address: smsData.address,
          code: smsData.code,
          sms: smsData.sms,
          id: smsData.id,
          isCompleted: isCompleted,
          lockerNumber: smsData.lockerNumber,
        );
      }).toList();

      final uncompletedNum = newList
          .where((s) => !s.isCompleted)
          .fold(0, (sum, s) => sum + s.code.split(', ').length);

      return ParcelData(
        address: parcel.address,
        smsDataList: newList,
        num: uncompletedNum,
      );
    }).toList();

    parcels.sort((a, b) {
      final aHas = a.num > 0 ? 0 : 1;
      final bHas = b.num > 0 ? 0 : 1;
      if (aHas != bHas) return aHas.compareTo(bHas);
      final aLatest = a.smsDataList.isNotEmpty ? a.smsDataList.first.sms.timestamp : 0;
      final bLatest = b.smsDataList.isNotEmpty ? b.smsDataList.first.sms.timestamp : 0;
      return bLatest.compareTo(aLatest);
    });

    return ProcessResult(successful, parcels, failed);
  }
}
