import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class IosColors {
  // iOS 17/18 Dark Mode Palette
  static const Color systemBackground = Color(0xFF000000);
  static const Color secondaryBackground = Color(0xFF1C1C1E);
  static const Color tertiaryBackground = Color(0xFF2C2C2E);
  static const Color elevatedBackground = Color(0xFF242426);
  static const Color cardBackground = Color(0xFF161618);

  // Apple System Accents
  static const Color systemBlue = Color(0xFF0A84FF);
  static const Color systemGreen = Color(0xFF30D158);
  static const Color systemIndigo = Color(0xFF5E5CE6);
  static const Color systemOrange = Color(0xFFFF9F0A);
  static const Color systemPurple = Color(0xFFBF5AF2);
  static const Color systemRed = Color(0xFFFF453A);
  static const Color systemTeal = Color(0xFF64D2FF);
  static const Color systemYellow = Color(0xFFFFD60A);

  // Labels & Text
  static const Color label = Color(0xFFFFFFFF);
  static const Color secondaryLabel = Color(0xFF8E8E93);
  static const Color tertiaryLabel = Color(0xFF636366);
  static const Color quaternaryLabel = Color(0xFF48484A);

  // Separators & Borders
  static const Color separator = Color(0x28FFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassHighlight = Color(0x15FFFFFF);
}

class IosTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: IosColors.systemBackground,
      primaryColor: IosColors.systemBlue,
      colorScheme: const ColorScheme.dark(
        primary: IosColors.systemBlue,
        secondary: IosColors.systemGreen,
        surface: IosColors.secondaryBackground,
      ),
      fontFamily: '.SF Pro Text',
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: IosColors.label,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: IosColors.systemBlue,
        barBackgroundColor: Color(0xCC000000),
        scaffoldBackgroundColor: IosColors.systemBackground,
        textTheme: CupertinoTextThemeData(
          primaryColor: IosColors.systemBlue,
          textStyle: TextStyle(
            color: IosColors.label,
            fontFamily: '.SF Pro Text',
            fontSize: 16,
            letterSpacing: -0.3,
          ),
        ),
      ),
      useMaterial3: true,
    );
  }
}

/// Reusable iOS Inset Grouped Container
class IosGroupedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const IosGroupedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: IosColors.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: IosColors.separator,
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: card,
      );
    }
    return card;
  }
}

/// iOS Section Header Label
class IosSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const IosSectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: IosColors.secondaryLabel,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// iOS Inset Row / List Tile with Icon, Title, Subtitle and Trailing
class IosListTile extends StatelessWidget {
  final Widget? leading;
  final IconData? leadingIcon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool isDestructive;

  const IosListTile({
    super.key,
    this.leading,
    this.leadingIcon,
    this.iconColor,
    this.iconBackgroundColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget? leadingWidget = leading;
    if (leadingWidget == null && leadingIcon != null) {
      leadingWidget = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: iconBackgroundColor ?? (iconColor ?? IosColors.systemBlue).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          leadingIcon,
          size: 18,
          color: iconColor ?? IosColors.systemBlue,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (leadingWidget != null) ...[
              leadingWidget,
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive ? IosColors.systemRed : IosColors.label,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: IosColors.secondaryLabel,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
            if (showChevron) ...[
              const SizedBox(width: 6),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: IosColors.tertiaryLabel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Thin iOS List Item Separator
class IosDivider extends StatelessWidget {
  final double indent;

  const IosDivider({super.key, this.indent = 0});

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: IosColors.separator,
      height: 1,
      thickness: 0.5,
      indent: indent,
    );
  }
}
