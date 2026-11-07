import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'phosphor_svg_fallback_data.dart';

/// Stable identifiers for BrowseIt's local Phosphor-style SVG icon set.
/// These IconData instances are keys only; all visible icons are painted from SVG.
class PhosphorIcons {
  static const IconData arrowClockwise = IconData(0xF0001, fontFamily: 'BrowseItSvg');
  static const IconData arrowLeft = IconData(0xF0002, fontFamily: 'BrowseItSvg');
  static const IconData arrowRight = IconData(0xF0003, fontFamily: 'BrowseItSvg');
  static const IconData arrowUp = IconData(0xF0004, fontFamily: 'BrowseItSvg');
  static const IconData arrowUpLeft = IconData(0xF0005, fontFamily: 'BrowseItSvg');
  static const IconData bookmarkSimple = IconData(0xF0006, fontFamily: 'BrowseItSvg');
  static const IconData bookmarksSimple = IconData(0xF0007, fontFamily: 'BrowseItSvg');
  static const IconData browser = IconData(0xF0008, fontFamily: 'BrowseItSvg');
  static const IconData calendar = IconData(0xF0037, fontFamily: 'BrowseItSvg');
  static const IconData caretDown = IconData(0xF0009, fontFamily: 'BrowseItSvg');
  static const IconData caretLeft = IconData(0xF000A, fontFamily: 'BrowseItSvg');
  static const IconData caretRight = IconData(0xF000B, fontFamily: 'BrowseItSvg');
  static const IconData caretUp = IconData(0xF000C, fontFamily: 'BrowseItSvg');
  static const IconData check = IconData(0xF000D, fontFamily: 'BrowseItSvg');
  static const IconData checkCircle = IconData(0xF000E, fontFamily: 'BrowseItSvg');
  static const IconData circle = IconData(0xF000F, fontFamily: 'BrowseItSvg');
  static const IconData circleDot = IconData(0xF0010, fontFamily: 'BrowseItSvg');
  static const IconData clockCounterClockwise = IconData(0xF0011, fontFamily: 'BrowseItSvg');
  static const IconData compass = IconData(0xF0012, fontFamily: 'BrowseItSvg');
  static const IconData copy = IconData(0xF0013, fontFamily: 'BrowseItSvg');
  static const IconData dotsThreeVertical = IconData(0xF0014, fontFamily: 'BrowseItSvg');
  static const IconData downloadSimple = IconData(0xF0015, fontFamily: 'BrowseItSvg');
  static const IconData envelopeSimple = IconData(0xF0016, fontFamily: 'BrowseItSvg');
  static const IconData eye = IconData(0xF0017, fontFamily: 'BrowseItSvg');
  static const IconData eyeSlash = IconData(0xF0018, fontFamily: 'BrowseItSvg');
  static const IconData fileArrowUp = IconData(0xF0019, fontFamily: 'BrowseItSvg');
  static const IconData gauge = IconData(0xF001A, fontFamily: 'BrowseItSvg');
  static const IconData gear = IconData(0xF001B, fontFamily: 'BrowseItSvg');
  static const IconData globe = IconData(0xF001C, fontFamily: 'BrowseItSvg');
  static const IconData house = IconData(0xF001D, fontFamily: 'BrowseItSvg');
  static const IconData image = IconData(0xF001E, fontFamily: 'BrowseItSvg');
  static const IconData info = IconData(0xF001F, fontFamily: 'BrowseItSvg');
  static const IconData link = IconData(0xF0020, fontFamily: 'BrowseItSvg');
  static const IconData list = IconData(0xF0021, fontFamily: 'BrowseItSvg');
  static const IconData listChecks = IconData(0xF0022, fontFamily: 'BrowseItSvg');
  static const IconData lockSimple = IconData(0xF0023, fontFamily: 'BrowseItSvg');
  static const IconData magnifyingGlass = IconData(0xF0024, fontFamily: 'BrowseItSvg');
  static const IconData mapPin = IconData(0xF0025, fontFamily: 'BrowseItSvg');
  static const IconData microphone = IconData(0xF0026, fontFamily: 'BrowseItSvg');
  static const IconData moon = IconData(0xF0027, fontFamily: 'BrowseItSvg');
  static const IconData palette = IconData(0xF0028, fontFamily: 'BrowseItSvg');
  static const IconData pencilSimple = IconData(0xF0029, fontFamily: 'BrowseItSvg');
  static const IconData plus = IconData(0xF002A, fontFamily: 'BrowseItSvg');
  static const IconData sealCheck = IconData(0xF002B, fontFamily: 'BrowseItSvg');
  static const IconData shield = IconData(0xF002C, fontFamily: 'BrowseItSvg');
  static const IconData shieldCheck = IconData(0xF002D, fontFamily: 'BrowseItSvg');
  static const IconData signIn = IconData(0xF002E, fontFamily: 'BrowseItSvg');
  static const IconData signOut = IconData(0xF002F, fontFamily: 'BrowseItSvg');
  static const IconData slidersHorizontal = IconData(0xF0030, fontFamily: 'BrowseItSvg');
  static const IconData sparkles = IconData(0xF0031, fontFamily: 'BrowseItSvg');
  static const IconData squaresFour = IconData(0xF0032, fontFamily: 'BrowseItSvg');
  static const IconData trash = IconData(0xF0033, fontFamily: 'BrowseItSvg');
  static const IconData uploadSimple = IconData(0xF0034, fontFamily: 'BrowseItSvg');
  static const IconData wifiSlash = IconData(0xF0035, fontFamily: 'BrowseItSvg');
  static const IconData x = IconData(0xF0036, fontFamily: 'BrowseItSvg');
}

class PhosphorSvgIcon extends StatelessWidget {
  const PhosphorSvgIcon(
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

  // Mantém o tamanho externo esperado pelo layout, mas desenha o SVG um pouco
  // menor. Isso reproduz a área visual mais contida dos Icon widgets do Flutter.
  static const double _visualScale = 0.88;

  static const Map<int, String> _assets = <int, String>{
    0xF0001: 'arrow-clockwise',
    0xF0002: 'arrow-left',
    0xF0003: 'arrow-right',
    0xF0004: 'arrow-up',
    0xF0005: 'arrow-up-left',
    0xF0006: 'bookmark-simple',
    0xF0007: 'bookmarks-simple',
    0xF0008: 'browser',
    0xF0009: 'caret-down',
    0xF000A: 'caret-left',
    0xF000B: 'caret-right',
    0xF000C: 'caret-up',
    0xF000D: 'check',
    0xF000E: 'check-circle',
    0xF000F: 'circle',
    0xF0010: 'circle-dot',
    0xF0011: 'clock-counter-clockwise',
    0xF0012: 'compass',
    0xF0013: 'copy',
    0xF0014: 'dots-three-vertical',
    0xF0015: 'download-simple',
    0xF0016: 'envelope-simple',
    0xF0017: 'eye',
    0xF0018: 'eye-slash',
    0xF0019: 'file-arrow-up',
    0xF001A: 'gauge',
    0xF001B: 'gear',
    0xF001C: 'globe',
    0xF001D: 'house',
    0xF001E: 'image',
    0xF001F: 'info',
    0xF0020: 'link',
    0xF0021: 'list',
    0xF0022: 'list-checks',
    0xF0023: 'lock-simple',
    0xF0024: 'magnifying-glass',
    0xF0025: 'map-pin',
    0xF0026: 'microphone',
    0xF0027: 'moon',
    0xF0028: 'palette',
    0xF0029: 'pencil-simple',
    0xF002A: 'plus',
    0xF002B: 'seal-check',
    0xF002C: 'shield',
    0xF002D: 'shield-check',
    0xF002E: 'sign-in',
    0xF002F: 'sign-out',
    0xF0030: 'sliders-horizontal',
    0xF0031: 'sparkles',
    0xF0032: 'squares-four',
    0xF0033: 'trash',
    0xF0034: 'upload-simple',
    0xF0035: 'wifi-slash',
    0xF0036: 'x',
    0xF0037: 'clock-counter-clockwise',
  };

  @override
  Widget build(BuildContext context) {
    final slug = _assets[icon.codePoint] ?? 'question';
    final variant = (fill ?? 0) >= .5 || (weight ?? 400) >= 600 ? 'fill' : 'regular';
    // Ao contrário do antigo valor fixo 24, herda o IconTheme local. Assim,
    // IconButton, AppBar, ListTile e campos de texto controlam o tamanho como
    // fariam com um Icon normal do Flutter.
    final iconSize = size ?? IconTheme.of(context).size ?? 24.0;
    final visualSize = iconSize * _visualScale;
    final svgAsset = 'assets/icons/phosphor/$variant/$slug.svg';
    final tint = color ?? IconTheme.of(context).color ?? Theme.of(context).iconTheme.color ?? Colors.black;

    SvgPicture svgFromString(String source) => SvgPicture.string(
          source,
          width: visualSize,
          height: visualSize,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
          semanticsLabel: semanticLabel,
        );

    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      child: SizedBox(
        width: iconSize,
        height: iconSize,
        child: Center(
          child: SvgPicture.asset(
            svgAsset,
            width: visualSize,
            height: visualSize,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
            semanticsLabel: semanticLabel,
            placeholderBuilder: (_) => SizedBox(width: visualSize, height: visualSize),
            errorBuilder: (context, error, stackTrace) {
              final fallback = phosphorSvgFallbackData['$variant:$slug'] ??
                  phosphorSvgFallbackData['$variant:question'];
              debugPrint('BrowseIt SVG asset fallback: $svgAsset ($error)');
              if (fallback == null) return SizedBox(width: visualSize, height: visualSize);
              return svgFromString(fallback);
            },
          ),
        ),
      ),
    );
  }
}
