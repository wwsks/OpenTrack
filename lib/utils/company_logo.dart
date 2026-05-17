import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CompanyLogo {
  static const Map<String, String> _logoMap = {
    '顺丰速运': 'shunfeng.png',
    '京东快递': 'jd.png',
    '京东物流': 'jd.png',
    '中通快递': 'zhongtong.png',
    '圆通速递': 'yuantong.png',
    '韵达快递': 'yunda.png',
    '申通快递': 'shentong.png',
    '极兔速递': 'jtexpress.png',
    '邮政快递': 'youzhengguonei.png',
    'EMS': 'youzhengguonei.png',
    '德邦快递': 'debang.svg',
    '菜鸟速递': 'danniao.png',
    '菜鸟驿站': 'danniao.png',
    '百世快递': 'huitongkuaidi.png',
    '丰巢柜': 'fengchao.png',
    '天猫': 'tmall.png',
    '拼多多': 'pinduoduo.png',
    '淘宝': 'taobao.png',
    '跨越速运': 'kuayue.png',
    '宅急送': 'zhaijisong.png',
    '优速': 'youshuwuliu.png',
  };

  static const Map<String, IconData> _iconFallback = {
    '顺丰速运': Icons.local_shipping,
    '京东快递': Icons.local_shipping,
    '中通快递': Icons.local_shipping,
    '圆通速递': Icons.local_shipping,
    '韵达快递': Icons.local_shipping,
    '申通快递': Icons.local_shipping,
    '极兔速递': Icons.local_shipping,
    '邮政快递': Icons.mail,
    'EMS': Icons.mail,
    '德邦快递': Icons.local_shipping,
    '菜鸟速递': Icons.inventory_2,
    '百世快递': Icons.local_shipping,
    '丰巢柜': Icons.lock_outline,
    '天猫': Icons.shopping_bag,
    '拼多多': Icons.local_grocery_store,
    '淘宝': Icons.shopping_bag,
  };

  static String? getAssetPath(String companyName) => _logoMap[companyName];

  static Widget buildLogo(String companyName, {double size = 28}) {
    final assetPath = getAssetPath(companyName);
    if (assetPath == null) return _fallbackIcon(companyName, size);

    final fullPath = 'assets/logos/$assetPath';
    final isSvg = assetPath.endsWith('.svg');

    Widget image;
    if (isSvg) {
      image = SvgPicture.asset(
        fullPath,
        width: size,
        height: size,
        placeholderBuilder: (_) => _fallbackIcon(companyName, size),
      );
    } else {
      image = Image.asset(
        fullPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallbackIcon(companyName, size),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.15),
      child: image,
    );
  }

  static Widget _fallbackIcon(String companyName, double size) {
    final icon = _iconFallback[companyName] ?? Icons.local_shipping;
    return Icon(icon, size: size * 0.7, color: Colors.grey);
  }
}
