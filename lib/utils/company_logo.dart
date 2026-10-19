import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/theme.dart';

/// 快递公司 Logo 统一渲染层（设计简报「快递 Logo 统一」）。
///
/// 渲染约定（素材不动，只统一渲染）：
/// - 所有 logo 渲染进 size×size、圆角 size*0.22 的统一底板：
///   浅色主题白底 + lightDivider 发丝描边；深色主题 darkCard 底 + darkDivider 描边；
/// - 素材 `BoxFit.contain` 展示，四边留 size*0.12 内边距；
/// - 无素材或加载失败一律走「品牌色首字母牌」（品牌色方牌 + 白色首字），
///   不再出现灰色通用图标。
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

  /// 常见快递公司品牌主色（首字母牌底色）
  static const Map<String, Color> _brandColors = {
    '顺丰速运': Color(0xFF1A1A1A),
    '中通快递': Color(0xFF0066CC),
    '圆通速递': Color(0xFFD9272E),
    '韵达快递': Color(0xFFF5A623),
    '申通快递': Color(0xFFF79400),
    '极兔速递': Color(0xFFE60012),
    '邮政快递': Color(0xFF009944),
    'EMS': Color(0xFF009944),
    '德邦快递': Color(0xFF00529E),
    '京东快递': Color(0xFFE1251B),
    '京东物流': Color(0xFFE1251B),
    '丰巢柜': Color(0xFF00A862),
  };

  /// 表外公司兜底调色板：6 色柔和调色板（均为白字可读的中低明度色），
  /// 按名字 hash 取色，保证同名恒同色
  static const List<Color> _hashPalette = [
    Color(0xFF2D6BE4), // 蓝
    Color(0xFF7B5BD6), // 紫
    Color(0xFFD64545), // 红
    Color(0xFFC97A2B), // 橙
    Color(0xFF1F8A8A), // 青
    Color(0xFF2E9E5B), // 绿
  ];

  /// 白字在品牌色上的最低对比度（首字母牌可读性下限）
  static const double _minContrastOnWhite = 3.5;

  static String? getAssetPath(String companyName) => _logoMap[companyName];

  /// 首字母牌底色：品牌色映射（必要时压暗保证白字可读）→ 表外公司 hash 调色板
  @visibleForTesting
  static Color brandPlateColorFor(String companyName) {
    final brand = _brandColorFor(companyName);
    return _readableOnWhite(brand ??
        _hashPalette[_stableHash(companyName) % _hashPalette.length]);
  }

  /// 统一底板渲染：size×size 圆角 size*0.22，素材 contain + 内边距，无素材/失败走首字母牌。
  /// 通过 Builder 取主题，保持 buildLogo 签名不变（调用方无需感知深浅主题）。
  static Widget buildLogo(String companyName, {double size = 28}) {
    final assetPath = getAssetPath(companyName);
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
            borderRadius: BorderRadius.circular(size * 0.22),
            border: Border.all(
              color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
              width: AppTheme.hairline,
            ),
          ),
          child: assetPath == null
              ? _brandPlate(companyName, size)
              // Center 不约束子件大小：加载失败时首字母牌可撑满整个底板
              : Center(child: _assetImage(assetPath, companyName, size)),
        );
      },
    );
  }

  /// 素材渲染：contain + 四边 size*0.12 内边距；SVG/PNG 同路径，加载失败/占位都回首字母牌
  static Widget _assetImage(String assetPath, String companyName, double size) {
    final fullPath = 'assets/logos/$assetPath';
    final inner = size * 0.76; // 四边留 size*0.12 内边距
    if (assetPath.endsWith('.svg')) {
      return SvgPicture.asset(
        fullPath,
        width: inner,
        height: inner,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => _brandPlate(companyName, size),
        errorBuilder: (_, _, _) => _brandPlate(companyName, size),
      );
    }
    return Image.asset(
      fullPath,
      width: inner,
      height: inner,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _brandPlate(companyName, size),
    );
  }

  /// 首字母牌：品牌色圆角方牌 + 白色首字（与统一底板同规格，随外层裁切）
  static Widget _brandPlate(String companyName, double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: brandPlateColorFor(companyName),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Text(
        _initialsOf(companyName),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }

  /// 首字：中文取首字符；纯英文/数字短名（如 EMS）取前 2 个字符大写
  static String _initialsOf(String companyName) {
    final name = companyName.trim();
    if (name.isEmpty) return '?';
    final isAscii = name.codeUnits.every((unit) => unit < 128);
    if (isAscii) {
      return name.substring(0, math.min(2, name.length)).toUpperCase();
    }
    return String.fromCharCode(name.runes.first);
  }

  /// 品牌色查找：精确匹配 → 全名包含品牌名（如「XX中通快递」）→ 品牌名包含短名（如「中通」）
  static Color? _brandColorFor(String companyName) {
    final name = companyName.trim();
    final exact = _brandColors[name];
    if (exact != null) return exact;
    for (final entry in _brandColors.entries) {
      if (name.contains(entry.key)) return entry.value;
    }
    if (name.length >= 2) {
      for (final entry in _brandColors.entries) {
        if (entry.key.contains(name)) return entry.value;
      }
    }
    return null;
  }

  /// 白字可读性保护：品牌色过亮时逐级压暗，直到白字对比度达到下限
  static Color _readableOnWhite(Color color) {
    var result = color;
    while (_contrastWithWhite(result) < _minContrastOnWhite) {
      final hsl = HSLColor.fromColor(result);
      if (hsl.lightness <= 0.12) break;
      result = hsl.withLightness(hsl.lightness - 0.03).toColor();
    }
    return result;
  }

  static double _contrastWithWhite(Color color) {
    return 1.05 / (_relativeLuminance(color) + 0.05);
  }

  /// WCAG 相对亮度（Color.r/g/b 为 0~1 浮点通道）
  static double _relativeLuminance(Color color) {
    double linear(double v) {
      return v <= 0.04045
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = linear(color.r);
    final g = linear(color.g);
    final b = linear(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// 稳定 hash（自实现，保证跨运行/平台同名恒同色，不依赖 String.hashCode）
  static int _stableHash(String name) {
    var hash = 0;
    for (final unit in name.runes) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}
