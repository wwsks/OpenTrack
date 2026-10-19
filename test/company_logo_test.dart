import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentrack/config/theme.dart';
import 'package:opentrack/utils/company_logo.dart';

/// 挂载 buildLogo：它通过 Builder 读取主题，需包一层 MaterialApp（可指定深浅主题）
Widget wrapLogo(Widget logo, {bool dark = false}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(body: Center(child: logo)),
  );
}

/// 找出指定底色的圆角底板装饰（首字母牌 / 统一底板）
BoxDecoration? findDecorationOfColor(WidgetTester tester, Color color) {
  for (final widget in tester.widgetList<Container>(find.byType(Container))) {
    final decoration = widget.decoration;
    if (decoration is BoxDecoration && decoration.color == color) {
      return decoration;
    }
  }
  return null;
}

/// WCAG 白字对比度（与 company_logo 内部算法一致，测试独立复算避免自证）
double contrastWithWhite(Color color) {
  double linear(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final luminance =
      0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b);
  return 1.05 / (luminance + 0.05);
}

void main() {
  group('首字母牌 fallback', () {
    testWidgets('无素材公司渲染首字符白字，不再出现灰色图标', (tester) async {
      await tester.pumpWidget(wrapLogo(CompanyLogo.buildLogo('未知速运', size: 28)));

      // 首字符 + 白字
      expect(find.text('未'), findsOneWidget);
      final text = tester.widget<Text>(find.text('未'));
      expect(text.style?.color, Colors.white);

      // 灰色通用图标已从正常路径移除
      expect(find.byType(Icon), findsNothing);

      // 首字母牌 = hash 调色板兜底色
      expect(
        findDecorationOfColor(tester, CompanyLogo.brandPlateColorFor('未知速运')),
        isNotNull,
      );
    });

    testWidgets('已知公司品牌色映射生效（短名命中映射表）', (tester) async {
      await tester.pumpWidget(wrapLogo(CompanyLogo.buildLogo('中通', size: 28)));

      expect(find.text('中'), findsOneWidget);
      // 「中通」命中中通蓝品牌色映射（0xFF0066CC 对比度足够、不压暗）
      expect(
        findDecorationOfColor(tester, const Color(0xFF0066CC)),
        isNotNull,
        reason: '「中通」应命中中通蓝品牌色映射',
      );
    });

    test('品牌色映射表取值生效', () {
      expect(CompanyLogo.brandPlateColorFor('顺丰速运'), const Color(0xFF1A1A1A));
      expect(CompanyLogo.brandPlateColorFor('中通快递'), const Color(0xFF0066CC));
      expect(CompanyLogo.brandPlateColorFor('圆通速递'), const Color(0xFFD9272E));
      expect(CompanyLogo.brandPlateColorFor('极兔速递'), const Color(0xFFE60012));
    });

    test('首字母牌品牌色白字对比度足够（过亮品牌色自动压暗）', () {
      const names = [
        '顺丰速运',
        '中通快递',
        '圆通速递',
        '韵达快递',
        '申通快递',
        '极兔速递',
        '邮政快递',
        '德邦快递',
        '京东快递',
        '丰巢柜',
        '未知速运',
        '随便一家快递',
      ];
      for (final name in names) {
        final color = CompanyLogo.brandPlateColorFor(name);
        expect(
          contrastWithWhite(color),
          greaterThanOrEqualTo(3.5),
          reason: '$name 首字母牌白字对比度不足（$color）',
        );
      }
    });
  });

  group('有素材公司', () {
    testWidgets('PNG 素材渲染进统一底板（Image）', (tester) async {
      await tester.pumpWidget(wrapLogo(CompanyLogo.buildLogo('顺丰速运', size: 28)));

      expect(find.byType(Image), findsOneWidget);
      // 统一底板：白底 + 发丝描边
      final plate = findDecorationOfColor(tester, AppTheme.lightCard);
      expect(plate, isNotNull);
      expect(plate!.borderRadius, BorderRadius.circular(28 * 0.22));
    });

    testWidgets('SVG 素材走同一底板路径（SvgPicture）', (tester) async {
      await tester.pumpWidget(wrapLogo(CompanyLogo.buildLogo('德邦快递', size: 28)));

      expect(find.byType(SvgPicture), findsOneWidget);
    });
  });

  group('统一底板主题描边', () {
    testWidgets('浅色主题白底 + lightDivider 发丝描边', (tester) async {
      await tester.pumpWidget(wrapLogo(CompanyLogo.buildLogo('顺丰速运', size: 28)));

      final plate = findDecorationOfColor(tester, AppTheme.lightCard);
      expect(plate, isNotNull);
      expect(plate!.border?.top.color, AppTheme.lightDivider);
    });

    testWidgets('深色主题 darkCard 底 + darkDivider 发丝描边', (tester) async {
      await tester.pumpWidget(wrapLogo(CompanyLogo.buildLogo('顺丰速运', size: 28), dark: true));

      final plate = findDecorationOfColor(tester, AppTheme.darkCard);
      expect(plate, isNotNull);
      expect(plate!.border?.top.color, AppTheme.darkDivider);
    });
  });
}
