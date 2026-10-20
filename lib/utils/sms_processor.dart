import 'package:shared_preferences/shared_preferences.dart';
import '../models/sms_model.dart';
import '../models/sms_data.dart';
import '../models/parcel_data.dart';
import 'address_normalizer.dart';
import 'sms_fallback_extractor.dart';
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
    AddressNormalizer? normalizer,
    SmsFallbackExtractor? fallback,
  }) async {
    await loadCustomRulesToParser(parser);
    final systemSms = await SmsUtil.readSmsByTimeFilter(7);
    return process(systemSms, parser, completedIds,
        normalizer: normalizer, fallback: fallback);
  }

  static Future<ProcessResult> process(
    List<SmsModel> messages,
    SmsParser parser,
    List<String> completedIds, {
    AddressNormalizer? normalizer,
    SmsFallbackExtractor? fallback,
  }) async {
    final successful = <SmsData>[];
    final failed = <SmsModel>[];

    for (final sms in messages) {
      final result = parser.parseSms(sms.body);

      if (result.success && result.code.isNotEmpty) {
        final combinedKey = '${sms.id}_${sms.timestamp}';
        final address = result.address.isNotEmpty ? result.address : '未知地址';

        successful.add(SmsData(
          address: address,
          code: result.code,
          sms: sms,
          id: combinedKey,
          lockerNumber: result.lockerNumber,
        ));
      } else {
        failed.add(sms);
      }
    }

    // LLM 兜底：正则失败的短信尝试提取，恢复的移出 failed 并入成功流（走同一分组管线）。
    // 提取失败/异常一律降级为现状，不影响主流程。
    if (fallback != null && failed.isNotEmpty) {
      try {
        final recovered = await fallback.extractFailed(List.of(failed));
        if (recovered.isNotEmpty) {
          final recoveredIds = recovered.map((s) => s.sms.id).toSet();
          failed.removeWhere((sms) => recoveredIds.contains(sms.id));
          successful.addAll(recovered);
        }
      } catch (_) {}
    }

    // 地址归一化：只对解析成功的地址做，failed 列表逻辑不变
    var mapping = const <String, String>{};
    if (normalizer != null && successful.isNotEmpty) {
      mapping =
          await normalizer.normalizeAll(successful.map((s) => s.address).toList());
    }

    // 用标准化地址作分组 key 与标题，SmsData.address 保持原始地址
    final parcelsMap = <String, ParcelData>{};
    for (final smsData in successful) {
      final groupKey = mapping[smsData.address] ?? smsData.address;
      final existingParcel = parcelsMap[groupKey];
      if (existingParcel != null) {
        final isDuplicate = existingParcel.smsDataList.any((existing) =>
            existing.code == smsData.code &&
            SmsUtil.isSameDay(existing.sms.timestamp, smsData.sms.timestamp));
        if (!isDuplicate) {
          existingParcel.smsDataList.add(smsData);
        }
      } else {
        parcelsMap[groupKey] = ParcelData(
          address: groupKey,
          smsDataList: [smsData],
        );
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
          extractedByLlm: smsData.extractedByLlm,
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
