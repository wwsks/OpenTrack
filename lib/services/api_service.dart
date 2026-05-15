import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/constants.dart';
import '../models/tracking_info.dart';
import '../utils/sign_util.dart';

class ApiService {
  final Dio _dio = Dio();

  Future<TrackingInfo> queryPackage({
    required String trackingNumber,
    required String companyCode,
    required String apiKey,
    required String customer,
    String? phone,
  }) async {
    final param = json.encode({
      'com': companyCode,
      'num': trackingNumber,
      'resultv2': '4',
      'show': '0',
      'order': 'desc',
      'lang': 'zh',
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });

    final sign = SignUtil.generateSign(param, apiKey, customer);

    try {
      final response = await _dio.post(
        AppConstants.apiBaseUrl,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
        data: {
          'customer': customer,
          'sign': sign,
          'param': param,
        },
      );

      final data = response.data;
      if (data is String) {
        return TrackingInfo.fromJson(json.decode(data));
      }
      return TrackingInfo.fromJson(data);
    } on DioException catch (e) {
      throw Exception('网络请求失败: ${e.message} (${e.type})');
    } catch (e) {
      throw Exception('查询失败: $e');
    }
  }

  /// 自动识别快递公司：逐个尝试常见快递公司
  Future<TrackingInfo?> autoDetectAndQuery({
    required String trackingNumber,
    required String apiKey,
    required String customer,
    String? phone,
  }) async {
    String lastError = '';
    for (final code in [
      'yuantong',
      'zhongtong',
      'shentong',
      'yunda',
      'jtexpress',
      'jd',
      'ems',
      'debangkuaidi',
      'youzhengguonei',
    ]) {
      try {
        final result = await queryPackage(
          trackingNumber: trackingNumber,
          companyCode: code,
          apiKey: apiKey,
          customer: customer,
          phone: phone,
        );
        if (result.data.isNotEmpty) {
          return result;
        }
      } catch (e) {
        lastError = e.toString();
        continue;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    if (lastError.isNotEmpty) {
      throw Exception(lastError);
    }
    return null;
  }
}
