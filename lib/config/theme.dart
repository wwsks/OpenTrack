import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../animations/pressable_card.dart';

class AppTheme {
  // Telegram-inspired palette
  static const Color primaryBlue = Color(0xFF3390EC);
  static const Color primaryDark = Color(0xFF5EB5F7);
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color accentRed = Color(0xFFE53935);
  static const Color accentPurple = Color(0xFF9C27B0);

  // Light theme colors
  static const Color lightBg = Color(0xFFF5F5F5);
  static const Color lightCard = Colors.white;
  static const Color lightAppBar = Colors.white;
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF8E8E93);
  static const Color lightDivider = Color(0xFFE5E5EA);

  // Dark theme colors (Telegram dark)
  static const Color darkBg = Color(0xFF0E1621);
  static const Color darkCard = Color(0xFF17212B);
  static const Color darkAppBar = Color(0xFF17212B);
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFF8E8E93);
  static const Color darkDivider = Color(0xFF2B3A47);

  // Status colors
  static const Color statusTransit = Color(0xFF3390EC);
  static const Color statusCollected = Color(0xFFFF9800);
  static const Color statusSigned = Color(0xFF4CAF50);
  static const Color statusDelivering = Color(0xFF9C27B0);
  static const Color statusProblem = Color(0xFFE53935);

  // ── 全局设计规范刻度（见 .superpowers/ui-polish/design-brief.md「全局设计规范」）──
  // 圆角刻度：小组件（chip/标签/图标底板）10、卡片/输入框/按钮 14、弹层/对话框 20
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;

  // 间距刻度：页面水平边距 16、卡片内边距 16、区块间距 20、行间距 8、图标与文字间距 10~12
  static const double spacePage = 16;
  static const double spaceBlock = 20;
  static const double spaceRow = 8;
  static const double spaceIconText = 10;

  // 字号刻度：辅助 12 / 次要 13 / 正文 15 / 卡片标题 16 / 页面大标题 20
  // 权重约定：标题 w600、正文 w400、辅助 w400 灰色；数字/单号可用 w600 突出
  static const double fontCaption = 12;
  static const double fontSecondary = 13;
  static const double fontBody = 15;
  static const double fontCardTitle = 16;
  static const double fontPageTitle = 20;

  // 发丝描边宽度：与 dividerTheme 一致（视觉 1px），深色主题卡片/底板/分隔线统一使用
  static const double hairline = 0.5;

  // 主按钮极轻纵向渐变（primaryBlue → 2E7FD4，约 8% 明度差，不花哨）；
  // ElevatedButton 主题只承载扁平底色与圆角，渐变按钮用 AppTheme.primaryButtonDecoration 包裹
  static const Color primaryBlueDeep = Color(0xFF2E7FD4);
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryBlue, primaryBlueDeep],
  );

  // 浅色卡片极轻环境阴影（alpha ≈ 0.04，不是浮空卡片）；
  // 深色主题不加阴影，只加 darkDivider 发丝描边（见 cardDecoration）
  static const List<BoxShadow> lightCardShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        primary: primaryBlue,
        surface: lightBg,
        onSurface: lightTextPrimary,
      ),
      scaffoldBackgroundColor: lightBg,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: lightTextPrimary),
        bodyMedium: TextStyle(color: lightTextPrimary),
        bodySmall: TextStyle(color: lightTextSecondary),
        titleLarge: TextStyle(color: lightTextPrimary),
        titleMedium: TextStyle(color: lightTextPrimary),
        titleSmall: TextStyle(color: lightTextPrimary),
        labelLarge: TextStyle(color: lightTextPrimary),
        labelMedium: TextStyle(color: lightTextPrimary),
        labelSmall: TextStyle(color: lightTextSecondary),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        // 去滚动 elevation，层级只用底部一条发丝分隔线表达
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: lightDivider, width: hairline),
        ),
        backgroundColor: lightAppBar,
        foregroundColor: lightTextPrimary,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: lightCard,
        // 卡片阴影不在 Card 上做（elevation 阴影不可控），统一走
        // AppTheme.cardDecoration / lightCardShadow 的极轻环境阴影
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        // 卡片间距节奏：垂直 4 → 相邻卡片 8px（行间距刻度）
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: lightDivider,
        thickness: 0.5,
        space: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryBlue,
        unselectedItemColor: lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: lightAppBar,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightDivider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        hintStyle: const TextStyle(color: lightTextSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        contentTextStyle: const TextStyle(fontSize: 14),
      ),
      // 开关选中态不填充整块轨道：轨道浅染主题色，拇指实色主题色（全部开关统一）
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? primaryBlue : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primaryBlue.withValues(alpha: 0.22)
              : lightTextSecondary.withValues(alpha: 0.22),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: primaryBlue,
        unselectedLabelColor: lightTextSecondary,
        indicatorColor: primaryBlue,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        elevation: 8,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
        showDragHandle: true,
        backgroundColor: lightCard,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryDark,
        brightness: Brightness.dark,
        primary: primaryDark,
        surface: darkBg,
        onSurface: darkTextPrimary,
      ),
      scaffoldBackgroundColor: darkBg,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkTextPrimary),
        bodyMedium: TextStyle(color: darkTextPrimary),
        bodySmall: TextStyle(color: darkTextSecondary),
        titleLarge: TextStyle(color: darkTextPrimary),
        titleMedium: TextStyle(color: darkTextPrimary),
        titleSmall: TextStyle(color: darkTextPrimary),
        labelLarge: TextStyle(color: darkTextPrimary),
        labelMedium: TextStyle(color: darkTextPrimary),
        labelSmall: TextStyle(color: darkTextSecondary),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        // 去滚动 elevation，层级只用底部一条发丝分隔线表达
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: darkDivider, width: hairline),
        ),
        backgroundColor: darkAppBar,
        foregroundColor: darkTextPrimary,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: darkCard,
        // 深色卡片不加阴影，只加 darkDivider 发丝描边勾勒边界
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: darkDivider, width: hairline),
        ),
        // 卡片间距节奏：垂直 4 → 相邻卡片 8px（行间距刻度）
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 0.5,
        space: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryDark,
        unselectedItemColor: darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: darkAppBar,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkDivider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryDark, width: 1.5),
        ),
        hintStyle: const TextStyle(color: darkTextSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          side: const BorderSide(color: primaryDark, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        contentTextStyle: const TextStyle(fontSize: 14),
      ),
      // 开关选中态不填充整块轨道：轨道浅染主题色，拇指实色主题色（全部开关统一）
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? primaryDark : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primaryDark.withValues(alpha: 0.30)
              : darkTextSecondary.withValues(alpha: 0.25),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: primaryDark,
        unselectedLabelColor: darkTextSecondary,
        indicatorColor: primaryDark,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        elevation: 8,
        backgroundColor: darkCard,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
        showDragHandle: true,
        backgroundColor: darkCard,
      ),
    );
  }

  // Status color helper
  static Color statusColor(String status) {
    switch (status) {
      case '0': return statusTransit;
      case '1': return statusCollected;
      case '3': return statusSigned;
      case '5': return statusDelivering;
      case '2': return statusProblem;
      default:  return Colors.grey;
    }
  }

  static String statusText(String status) {
    switch (status) {
      case '0': return '在途';
      case '1': return '揽收';
      case '5': return '派件';
      case '3': return '签收';
      case '2': return '疑难';
      default:  return '未知';
    }
  }

  // ── 通用样式辅助构建方法（ThemeData 承载不了的约定，统一从这里取）──

  /// 卡片装饰：浅色 = 卡片色 + 极轻环境阴影；深色 = 卡片色 + 发丝描边（不加阴影）。
  /// 自定义容器（Container/DecoratedBox 卡片）统一用它，不要各自写阴影/描边。
  static BoxDecoration cardDecoration(BuildContext context, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: color ?? (isDark ? darkCard : lightCard),
      borderRadius: BorderRadius.circular(radiusMd),
      border: isDark
          ? Border.all(color: darkDivider, width: hairline)
          : null,
      boxShadow: isDark ? null : lightCardShadow,
    );
  }

  /// 主按钮装饰：极轻纵向渐变 + 圆角 14。
  /// ElevatedButton 主题无法承载渐变，需要渐变按钮时用 Container + 本装饰包裹，
  /// 文字用白色 w600，按压反馈沿用 PressableCard。
  static BoxDecoration primaryButtonDecoration({double radius = radiusMd}) {
    return BoxDecoration(
      gradient: primaryGradient,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// 状态 pill 内边距：水平 10 / 垂直 4
  static const EdgeInsets statusPillPadding =
      EdgeInsets.symmetric(horizontal: 10, vertical: 4);

  /// 状态 pill 底色：圆角 10、底 = 状态色 12% 透明度
  static BoxDecoration statusPillDecoration(Color statusColor) {
    return BoxDecoration(
      color: statusColor.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(radiusSm),
    );
  }

  /// 状态 pill 文字：状态色、12 w600（状态色映射沿用 statusColor/statusText）
  static TextStyle statusPillTextStyle(Color statusColor) {
    return TextStyle(
      color: statusColor,
      fontSize: fontCaption,
      fontWeight: FontWeight.w600,
    );
  }

  /// 图标底板装饰：圆角 8、底 = 图标色 12% 透明度（取代裸图标）
  static BoxDecoration iconPlateDecoration(Color iconColor, {double radius = 8}) {
    return BoxDecoration(
      color: iconColor.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// 图标底板：32x32 着色底板 + 图标本色，设置页/功能入口前导图标统一使用
  static Widget iconPlate(IconData icon,
      {Color color = primaryBlue, double size = 32}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: iconPlateDecoration(color),
      child: Icon(icon, size: size * 0.55, color: color),
    );
  }

  /// 文字主色：按主题亮度取显式文字色（不依赖 ColorScheme 默认值）
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextPrimary
          : lightTextPrimary;

  /// 文字次色：按主题亮度取显式文字色
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextSecondary
          : lightTextSecondary;

  /// 主题强调蓝：浅色 primaryBlue / 深色 primaryDark（图标、强调文案等统一取它）
  static Color accent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? primaryDark
          : primaryBlue;

  /// 分区标题：4px 主色小竖条前缀 + 13 w600 次要色
  static Widget sectionTitle(String title) {
    return Builder(builder: (context) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: fontSecondary,
            decoration: BoxDecoration(
              color: accent(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: spaceRow),
          Text(
            title,
            style: TextStyle(
              fontSize: fontSecondary,
              fontWeight: FontWeight.w600,
              color: textSecondary(context),
            ),
          ),
        ],
      );
    });
  }

  /// 空状态：64px 着色圆底 + 品牌色图标 + 一句话说明（次要色 13px），可带一行 12px 提示。
  /// [color] 覆盖圆底/图标色（如错误态传 accentRed），默认品牌强调色
  static Widget emptyState(
    BuildContext context, {
    required IconData icon,
    required String message,
    String? hint,
    Color? color,
  }) {
    final accentColor = color ?? accent(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: accentColor),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: TextStyle(
            fontSize: fontSecondary,
            color: textSecondary(context),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: spaceRow),
          Text(
            hint,
            style: TextStyle(
              fontSize: fontCaption,
              color: textSecondary(context),
            ),
          ),
        ],
      ],
    );
  }

  /// 主按钮（极轻渐变）：白色 w600 文案 + PressableCard 按压反馈。
  /// 页面主行动作（查询、生成取件清单等）统一用它，次要动作用 OutlinedButton；
  /// [onTap] 为 null / [enabled] 为 false / [busy] 为 true 时降透明度且不可点。
  static Widget primaryButton({
    required String label,
    VoidCallback? onTap,
    IconData? icon,
    bool enabled = true,
    bool busy = false,
  }) {
    final active = enabled && !busy && onTap != null;
    return Opacity(
      opacity: active ? 1 : 0.5,
      child: PressableCard(
        onTap: active ? onTap : null,
        borderRadius: BorderRadius.circular(radiusMd),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: primaryButtonDecoration(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              else if (icon != null)
                Icon(icon, size: 18, color: Colors.white),
              if (busy || icon != null) const SizedBox(width: spaceRow),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: fontBody,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
