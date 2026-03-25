import 'package:flutter/material.dart';

class AppColors {
  // Extracted from zent-web/src/index.css CSS variables (HSL -> RGB):
  // light :root
  static const backgroundLight = Color(0xFFF7F8FB); // hsl(220 20% 97%)
  static const foregroundLight = Color(0xFF131A20); // hsl(220 25% 10%)
  static const cardLight = Color(0xFFFFFFFF);
  static const mutedLight = Color(0xFFEBEDF0); // hsl(220 14% 92%)
  static const mutedForegroundLight = Color(0xFF4B5563); // boosted for readability
  static const borderLight = Color(0xFFE7E9EC); // hsl(220 13% 91%)

  // dark
  static const backgroundDark = Color(0xFF0E1015); // hsl(222 30% 8%)
  static const foregroundDark = Color(0xFFF1F5FA); // hsl(210 40% 95%)
  static const cardDark = Color(0xFF171A22); // hsl(222 25% 12%)
  static const mutedDark = Color(0xFF252834); // hsl(222 20% 18%)
  static const mutedForegroundDark = Color(0xFF8B95A7); // hsl(215 20% 60%)
  static const borderDark = Color(0xFF292C39); // hsl(222 20% 20%)

  // amoled
  static const backgroundAmoled = Color(0xFF000000);
  static const foregroundAmoled = Color(0xFFF2F2F2); // hsl(0 0% 95%)
  static const cardAmoled = Color(0xFF0A0A0A); // hsl(0 0% 4%)
  static const mutedAmoled = Color(0xFF141414); // hsl(0 0% 8%)
  static const mutedForegroundAmoled = Color(0xFF8C8C8C); // hsl(0 0% 55%)
  static const borderAmoled = Color(0xFF1F1F1F); // hsl(0 0% 12%)

  // accents (shared)
  static const primary = Color(0xFF7C3AED); // hsl(262 83% 58%)
  static const secondary = Color(0xFF0EA5E9); // hsl(199 89% 48%)
  static const accent = Color(0xFFEC4899); // hsl(330 81% 60%)
  static const success = Color(0xFF22C55E); // hsl(152 69% 45%)
  static const warning = Color(0xFFF59E0B); // hsl(38 92% 50%)
  static const destructive = Color(0xFFEF4444); // hsl(0 84% 60%)

  // Glass vars (index.css)
  static const glassBgLight = Color(0x99FFFFFF); // hsla(0,0%,100%,0.6)
  static const glassBorderLight = Color(0x4DFFFFFF); // hsla(0,0%,100%,0.3)

  static const glassBgDark = Color(0xB3171A22); // hsla(222,25%,12%,0.7)
  static const glassBorderDark = Color(0x14FFFFFF); // hsla(0,0%,100%,0.08)

  static const glassBgAmoled = Color(0xCC0A0A0A); // hsla(0,0%,4%,0.8)
  static const glassBorderAmoled = Color(0x0FFFFFFF); // hsla(0,0%,100%,0.06)

  // Gradients (from --gradient-primary etc)
  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );
  static const gradientAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, primary],
  );
  static const gradientWarm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warning, accent],
  );
}

