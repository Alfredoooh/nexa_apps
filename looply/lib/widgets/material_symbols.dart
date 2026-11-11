import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Ícones centralizados exclusivamente no conjunto oficial Material Symbols
/// Rounded. Os aliases preservam a API anterior enquanto todas as telas
/// passam a usar a mesma família tipográfica arredondada.
class AppIcons {
  static const IconData arrowClockwise = Symbols.refresh_rounded;
  static const IconData arrowLeft = Symbols.arrow_back_rounded;
  static const IconData arrowRight = Symbols.arrow_forward_rounded;
  static const IconData arrowUp = Symbols.arrow_upward_rounded;
  static const IconData arrowUpLeft = Symbols.north_west_rounded;
  static const IconData bookmarkSimple = Symbols.bookmark_rounded;
  static const IconData bookmarksSimple = Symbols.bookmarks_rounded;
  static const IconData browser = Symbols.web_rounded;
  static const IconData calendar = Symbols.calendar_month_rounded;
  static const IconData caretDown = Symbols.keyboard_arrow_down_rounded;
  static const IconData caretLeft = Symbols.chevron_left_rounded;
  static const IconData caretRight = Symbols.chevron_right_rounded;
  static const IconData caretUp = Symbols.keyboard_arrow_up_rounded;
  static const IconData check = Symbols.check_rounded;
  static const IconData checkCircle = Symbols.check_circle_rounded;
  static const IconData circle = Symbols.circle_rounded;
  static const IconData circleDot = Symbols.radio_button_checked_rounded;
  static const IconData clockCounterClockwise = Symbols.history_rounded;
  static const IconData compass = Symbols.explore_rounded;
  static const IconData copy = Symbols.content_copy_rounded;
  static const IconData dotsThreeVertical = Symbols.more_vert_rounded;
  static const IconData downloadSimple = Symbols.download_rounded;
  static const IconData envelopeSimple = Symbols.mail_rounded;
  static const IconData eye = Symbols.visibility_rounded;
  static const IconData eyeSlash = Symbols.visibility_off_rounded;
  static const IconData fileArrowUp = Symbols.upload_file_rounded;
  static const IconData gauge = Symbols.speed_rounded;
  static const IconData gear = Symbols.settings_rounded;
  static const IconData globe = Symbols.public_rounded;
  static const IconData house = Symbols.home_rounded;
  static const IconData image = Symbols.image_rounded;
  static const IconData info = Symbols.info_rounded;
  static const IconData link = Symbols.link_rounded;
  static const IconData list = Symbols.list_rounded;
  static const IconData listChecks = Symbols.checklist_rounded;
  static const IconData lockSimple = Symbols.lock_rounded;
  static const IconData magnifyingGlass = Symbols.search_rounded;
  static const IconData mapPin = Symbols.location_on_rounded;
  static const IconData microphone = Symbols.mic_rounded;
  static const IconData moon = Symbols.dark_mode_rounded;
  static const IconData palette = Symbols.palette_rounded;
  static const IconData pencilSimple = Symbols.edit_rounded;
  static const IconData plus = Symbols.add_rounded;
  static const IconData sealCheck = Symbols.verified_rounded;
  static const IconData shield = Symbols.shield_rounded;
  static const IconData shieldCheck = Symbols.verified_user_rounded;
  static const IconData signIn = Symbols.login_rounded;
  static const IconData signOut = Symbols.logout_rounded;
  static const IconData slidersHorizontal = Symbols.tune_rounded;
  static const IconData sparkles = Symbols.auto_awesome_rounded;
  static const IconData squaresFour = Symbols.grid_view_rounded;
  static const IconData trash = Symbols.delete_rounded;
  static const IconData uploadSimple = Symbols.upload_rounded;
  static const IconData wifiSlash = Symbols.wifi_off_rounded;
  static const IconData x = Symbols.close_rounded;
  static const IconData warningCircle = Symbols.warning_rounded;
  static const IconData incognito = Symbols.masks_rounded;
}

/// Wrapper compatível com os antigos pontos de utilização de ícones.
/// Desenha diretamente a fonte Material Symbols Rounded, sem SVG, assets
/// vetoriais próprios ou fallbacks personalizados.
class AppMaterialIcon extends StatelessWidget {
  const AppMaterialIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.fill,
    this.weight,
    this.grade,
    this.opticalSize,
    this.shadows,
    this.semanticLabel,
    this.textDirection,
    this.applyTextScaling,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final double? fill;
  final double? weight;
  final double? grade;
  final double? opticalSize;
  final List<Shadow>? shadows;
  final String? semanticLabel;
  final TextDirection? textDirection;
  final bool? applyTextScaling;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color,
      fill: fill,
      weight: weight,
      grade: grade,
      opticalSize: opticalSize,
      shadows: shadows,
      semanticLabel: semanticLabel,
      textDirection: textDirection,
      applyTextScaling: applyTextScaling,
    );
  }
}
