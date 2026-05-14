import 'dart:convert';
import 'package:flutter/services.dart';

class ExpressCompany {
  final String name;
  final String code;
  final String type;

  ExpressCompany({required this.name, required this.code, required this.type});

  factory ExpressCompany.fromJson(Map<String, dynamic> json) {
    return ExpressCompany(
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      type: json['type'] ?? '',
    );
  }
}

class CompanyUtil {
  static List<ExpressCompany>? _companies;

  static Future<List<ExpressCompany>> loadCompanies() async {
    if (_companies != null) return _companies!;
    final jsonStr = await rootBundle.loadString('assets/data/companies.json');
    final List<dynamic> jsonList = json.decode(jsonStr);
    _companies = jsonList.map((e) => ExpressCompany.fromJson(e)).toList();
    return _companies!;
  }

  static Future<List<ExpressCompany>> searchCompanies(String query) async {
    final companies = await loadCompanies();
    if (query.isEmpty) return companies;
    final lower = query.toLowerCase();
    return companies
        .where((c) =>
            c.name.toLowerCase().contains(lower) ||
            c.code.toLowerCase().contains(lower))
        .toList();
  }

  /// 常见快递公司编码，用于自动识别
  static const List<String> commonCompanyCodes = [
    'yuantong',
    'zhongtong',
    'shentong',
    'shunfeng',
    'yunda',
    'jtexpress',
    'jd',
    'ems',
    'debangkuaidi',
    'youzhengguonei',
    'annengwuliu',
    'kuayue',
  ];
}
