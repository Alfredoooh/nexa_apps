// ══════════════════════════════════════════════════════════════
// FILE: lib/core/widgets/widgets.dart
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../core/theme/colors.dart';

// ══════════════════════════════════════════════════════════════
// MATERIAL SYMBOLS ROUNDED — ÍCONES OFICIAIS
// ══════════════════════════════════════════════════════════════

/// Centraliza os glifos Material Symbols Rounded para que todas as telas
/// utilizem exatamente a mesma família, métrica e desenho.
class RoundedSymbols {
  RoundedSymbols._();

  static const arrowBack = Symbols.arrow_back_rounded;
  static const arrowForward = Symbols.arrow_forward_rounded;
  static const chevronLeft = Symbols.chevron_left_rounded;
  static const chevronRight = Symbols.chevron_right_rounded;
  static const chevronForward = Symbols.chevron_forward_rounded;
  static const expandLess = Symbols.expand_less_rounded;
  static const expandMore = Symbols.expand_more_rounded;
  static const keyboardArrowDown = Symbols.keyboard_arrow_down_rounded;
  static const moreVert = Symbols.more_vert_rounded;
  static const menu = Symbols.menu_rounded;
  static const close = Symbols.close_rounded;
  static const cancel = Symbols.cancel_rounded;
  static const check = Symbols.check_rounded;
  static const checkCircle = Symbols.check_circle_rounded;
  static const add = Symbols.add_rounded;
  static const remove = Symbols.remove_rounded;
  static const search = Symbols.search_rounded;
  static const searchOff = Symbols.search_off_rounded;
  static const refresh = Symbols.refresh_rounded;
  static const psychology = Symbols.psychology_rounded;
  static const smartToy = Symbols.smart_toy_rounded;
  static const stacks = Symbols.stacks_rounded;
  static const layers = Symbols.layers_rounded;
  static const edit = Symbols.edit_rounded;
  static const autoAwesome = Symbols.auto_awesome_rounded;
  static const public = Symbols.public_rounded;
  static const language = Symbols.language_rounded;
  static const eventBusy = Symbols.event_busy_rounded;
  static const calendarMonth = Symbols.calendar_month_rounded;
  static const myLocation = Symbols.my_location_rounded;
  static const locationOff = Symbols.location_off_rounded;
  static const bookmark = Symbols.bookmark_rounded;
  static const star = Symbols.star_rounded;
  static const chatBubble = Symbols.chat_bubble_rounded;
  static const chat = Symbols.chat_rounded;
  static const addComment = Symbols.add_comment_rounded;
  static const radioButtonChecked = Symbols.radio_button_checked_rounded;
  static const pictureAsPdf = Symbols.picture_as_pdf_rounded;
  static const description = Symbols.description_rounded;
  static const download = Symbols.download_rounded;
  static const openInFull = Symbols.open_in_full_rounded;
  static const visibilityOff = Symbols.visibility_off_rounded;
  static const arrowDownward = Symbols.arrow_downward_rounded;
  static const keyboardReturn = Symbols.keyboard_return_rounded;
  static const pushPin = Symbols.push_pin_rounded;
  static const settings = Symbols.settings_rounded;
  static const logout = Symbols.logout_rounded;
  static const warning = Symbols.warning_rounded;
  static const localLibrary = Symbols.local_library_rounded;
  static const musicNote = Symbols.music_note_rounded;
  static const skipPrevious = Symbols.skip_previous_rounded;
  static const skipNext = Symbols.skip_next_rounded;
  static const playArrow = Symbols.play_arrow_rounded;
  static const playCircle = Symbols.play_circle_rounded;
  static const pause = Symbols.pause_rounded;
  static const pauseCircle = Symbols.pause_circle_rounded;
  static const cloudOff = Symbols.cloud_off_rounded;
  static const lock = Symbols.lock_rounded;
  static const error = Symbols.error_rounded;
  static const image = Symbols.image_rounded;
  static const imageNotSupported = Symbols.image_not_supported_rounded;
  static const insertDriveFile = Symbols.insert_drive_file_rounded;
  static const formatAlignCenter = Symbols.format_align_center_rounded;
  static const formatAlignLeft = Symbols.format_align_left_rounded;
  static const formatAlignRight = Symbols.format_align_right_rounded;
  static const formatAlignJustify = Symbols.format_align_justify_rounded;
  static const formatBold = Symbols.format_bold_rounded;
  static const brush = Symbols.brush_rounded;
  static const formatListBulleted = Symbols.format_list_bulleted_rounded;
  static const formatSize = Symbols.format_size_rounded;
  static const insertChart = Symbols.insert_chart_rounded;
  static const editNote = Symbols.edit_note_rounded;
  static const inkEraser = Symbols.ink_eraser_rounded;
  static const fontDownload = Symbols.font_download_rounded;
  static const textFields = Symbols.text_fields_rounded;
  static const link = Symbols.link_rounded;
  static const formatIndentDecrease = Symbols.format_indent_decrease_rounded;
  static const formatIndentIncrease = Symbols.format_indent_increase_rounded;
  static const contentPaste = Symbols.content_paste_rounded;
  static const formatQuote = Symbols.format_quote_rounded;
  static const aspectRatio = Symbols.aspect_ratio_rounded;
  static const height = Symbols.height_rounded;
  static const width = Symbols.width_rounded;
  static const spellcheck = Symbols.spellcheck_rounded;
  static const subscript = Symbols.subscript_rounded;
  static const superscript = Symbols.superscript_rounded;
  static const formatColorText = Symbols.format_color_text_rounded;
  static const formatUnderlined = Symbols.format_underlined_rounded;
  static const share = Symbols.share_rounded;
  static const delete = Symbols.delete_rounded;
  static const gridView = Symbols.grid_view_rounded;
  static const viewAgenda = Symbols.view_agenda_rounded;
  static const viewColumn = Symbols.view_column_rounded;
  static const strikethrough = Symbols.strikethrough_s_rounded;
  static const formatListNumbered = Symbols.format_list_numbered_rounded;
  static const category = Symbols.category_rounded;
  static const flipToFront = Symbols.flip_to_front_rounded;
  static const flipToBack = Symbols.flip_to_back_rounded;
  static const undo = Symbols.undo_rounded;
  static const redo = Symbols.redo_rounded;
  static const screenRotation = Symbols.screen_rotation_rounded;
  static const verticalAlignTop = Symbols.vertical_align_top_rounded;
  static const verticalAlignBottom = Symbols.vertical_align_bottom_rounded;
  static const margin = Symbols.margin_rounded;
  static const formatColorFill = Symbols.format_color_fill_rounded;
  static const code = Symbols.code_rounded;
  static const tableChart = Symbols.table_chart_rounded;
  static const slideshow = Symbols.slideshow_rounded;
  static const apps = Symbols.apps_rounded;
  static const accountTree = Symbols.account_tree_rounded;
  static const handyman = Symbols.handyman_rounded;
  static const cameraSwitch = Symbols.cameraswitch_rounded;
  static const flashOn = Symbols.flash_on_rounded;
  static const flashOff = Symbols.flash_off_rounded;
  static const map = Symbols.map_rounded;
  static const info = Symbols.info_rounded;
  static const folder = Symbols.folder_rounded;
  static const fileCopy = Symbols.file_copy_rounded;
  static const person = Symbols.person_rounded;
  static const email = Symbols.email_rounded;
  static const visibility = Symbols.visibility_rounded;
  static const lightMode = Symbols.light_mode_rounded;
  static const darkMode = Symbols.dark_mode_rounded;
  static const formatShapes = Symbols.format_shapes_rounded;
  static const autoFixHigh = Symbols.auto_fix_high_rounded;
  static const tableRows = Symbols.table_rows_rounded;
  static const fontSize = Symbols.format_size_rounded;
  static const extension = Symbols.extension_rounded;
  static const schedule = Symbols.schedule_rounded;

  static IconData fromAssetName(String source) {
    final name = source.toLowerCase().replaceAll('.svg', '').trim();
    return switch (name) {
      'back' || 'arrow_back' || 'arrow_back_ios' => arrowBack,
      'forward' || 'arrow_forward' => arrowForward,
      'chevron_left' => chevronLeft,
      'chevron_right' || 'chevron_forward' || 'chevron_right.svg' => chevronForward,
      'chevron_down' => keyboardArrowDown,
      'chevron_up' => expandLess,
      'close' => close,
      'close_circular' => cancel,
      'check' || 'check.svg' => check,
      'checkmark_circle' => checkCircle,
      'add' || 'plus' => add,
      'minus' => remove,
      'search' => search,
      'search_off' => searchOff,
      'refresh' => refresh,
      'brain' => psychology,
      'robot' || 'ai' => smartToy,
      'stacks' => stacks,
      'layers' => layers,
      'pencil' || 'edit' => edit,
      'star' => star,
      'globe' || 'public' => public,
      'language' => language,
      'calendar_off' => eventBusy,
      'calendar' => calendarMonth,
      'my_location' => myLocation,
      'location_off' => locationOff,
      'bookmark' || 'bookmarks' => bookmark,
      'comment' => chatBubble,
      'chat' => chat,
      'new_chat' => addComment,
      'return' => keyboardReturn,
      'pin' => pushPin,
      'settings' => settings,
      'logout' => logout,
      'more' || 'more_vert' => moreVert,
      'menu' => menu,
      'library' => localLibrary,
      'error' || 'error.svg' => error,
      'warning' => warning,
      'pdf' => pictureAsPdf,
      'description' => description,
      'expand' => openInFull,
      'download' => download,
      'incognito' => visibilityOff,
      'arrow_down' => arrowDownward,
      'record' => radioButtonChecked,
      'skip_previous' => skipPrevious,
      'skip_next' => skipNext,
      'music_note' => musicNote,
      'play' || 'play_arrow' => playArrow,
      'play_circle' || 'play_circle_fill' => playCircle,
      'pause' => pause,
      'pause_circle' || 'pause_circle_filled' => pauseCircle,
      'cloud_off' => cloudOff,
      'lock' || 'lock_outline' => lock,
      'image' => image,
      'image_not_supported' => imageNotSupported,
      'insert_drive_file' || 'file' => insertDriveFile,
      'align_center' => formatAlignCenter,
      'align_left' => formatAlignLeft,
      'align_right' => formatAlignRight,
      'justify' || 'align_justify' => formatAlignJustify,
      'bold' => formatBold,
      'brush' => brush,
      'bullet_point' || 'bullet' => formatListBulleted,
      'capital_letter' || 'font-2' => textFields,
      'chart' => insertChart,
      'edit_text' => editNote,
      'eraser' => inkEraser,
      'font' => fontDownload,
      'font_size' => formatSize,
      'hyperlink' => link,
      'indent_decrease' => formatIndentDecrease,
      'indent_increase' => formatIndentIncrease,
      'paste' => contentPaste,
      'pencil_holder' => edit,
      'quote' => formatQuote,
      'resize' => aspectRatio,
      'spacing_height' => height,
      'spacing_width' => width,
      'spellcheck' => spellcheck,
      'subscript' => subscript,
      'superscript' => superscript,
      'text_color' => formatColorText,
      'underline' => formatUnderlined,
      'share' => share,
      'trash' || 'delete' => delete,
      'grid' => gridView,
      'row' => tableRows,
      'column' => viewColumn,
      'strike' => strikethrough,
      'numbered' => formatListNumbered,
      'shapes' => formatShapes,
      'bring_to_front' => flipToFront,
      'send_to_back' => flipToBack,
      'undo' => undo,
      'redo' => redo,
      'page_numbering' => formatListNumbered,
      'page_orientation' => screenRotation,
      'header' => verticalAlignTop,
      'footer' => verticalAlignBottom,
      'margins' => margin,
      'wand' => autoFixHigh,
      'theme' || 'sun' => lightMode,
      'moon' => darkMode,
      'tools' || 'plugins' => handyman,
      'clock' => schedule,
      'extension' => extension,
      _ => apps,
    };
  }
}

class AppIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color color;
  final bool useColorAsset;

  const AppIcon(
    this.asset, {
    super.key,
    this.size = 20,
    required this.color,
    this.useColorAsset = false,
  });

  @override
  Widget build(BuildContext context) => Icon(
        RoundedSymbols.fromAssetName(asset),
        size: size,
        color: color,
        semanticLabel: asset.replaceAll('.svg', '').replaceAll('_', ' '),
      );
}

class EditorTypeIcon extends StatelessWidget {
  final String asset;
  final double size;
  const EditorTypeIcon(this.asset, {super.key, this.size = 20});

  @override
  Widget build(BuildContext context) => AppIcon(
        asset,
        size: size,
        color: Theme.of(context).colorScheme.onSurface,
      );
}

// ══════════════════════════════════════════════════════════════
// TAP AREA
// ══════════════════════════════════════════════════════════════

class AppTap extends StatefulWidget {
  final VoidCallback onTap;
  final AppColorScheme s;
  final Widget child;
  final double size;

  const AppTap({
    super.key,
    required this.onTap,
    required this.s,
    required this.child,
    this.size = 36,
  });

  @override
  State<AppTap> createState() => _AppTapState();
}

class _AppTapState extends State<AppTap> {
  bool _p = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _p = true),
        onTapCancel: () => setState(() => _p = false),
        onTapUp: (_) => setState(() => _p = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _p ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _p ? widget.s.pressed : Colors.transparent,
              borderRadius: BorderRadius.circular(widget.size / 2),
            ),
            child: widget.child,
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// SWITCH
// ══════════════════════════════════════════════════════════════

class AppSwitch extends StatelessWidget {
  final bool value;
  final AppColorScheme s;
  final ValueChanged<bool> onChanged;
  const AppSwitch({
    super.key,
    required this.value,
    required this.s,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 46,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? s.primary : s.outline,
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? s.onPrimary : s.cardBackground,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// DASHED ROUNDED BORDER
// ══════════════════════════════════════════════════════════════

class DashedRRectBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;
  DashedRRectBorderPainter({
    required this.color,
    required this.radius,
    this.dashWidth = 5,
    this.dashGap = 4,
    this.strokeWidth = 1.3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2,
          size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRRectBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class DashedRRectBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  const DashedRRectBorder({
    super.key,
    required this.child,
    required this.color,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: DashedRRectBorderPainter(color: color, radius: radius),
        child: child,
      );
}

// ══════════════════════════════════════════════════════════════
// GENERIC BOTTOM SHEET CARD
// ══════════════════════════════════════════════════════════════

class SettingsStyleCard extends StatelessWidget {
  final AppColorScheme s;
  final BorderRadius radius;
  final Widget child;
  const SettingsStyleCard({
    super.key,
    required this.s,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: s.cardBackground, borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class SheetOptionsGroup extends StatelessWidget {
  final AppColorScheme s;
  final List<Widget> options;
  const SheetOptionsGroup({super.key, required this.s, required this.options});

  static const double _outerRadius = 16;
  static const double _innerRadius = 4;
  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    final count = options.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: _gap),
          SettingsStyleCard(
            s: s,
            radius: _radiusFor(i, count),
            child: options[i],
          ),
        ],
      ],
    );
  }

  BorderRadius _radiusFor(int index, int count) {
    if (count == 1) return BorderRadius.circular(_outerRadius);
    final isFirst = index == 0;
    final isLast = index == count - 1;
    return BorderRadius.only(
      topLeft: Radius.circular(isFirst ? _outerRadius : _innerRadius),
      topRight: Radius.circular(isFirst ? _outerRadius : _innerRadius),
      bottomLeft: Radius.circular(isLast ? _outerRadius : _innerRadius),
      bottomRight: Radius.circular(isLast ? _outerRadius : _innerRadius),
    );
  }
}

class SheetGrabber extends StatelessWidget {
  final AppColorScheme s;
  const SheetGrabber({super.key, required this.s});

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: s.outline,
          borderRadius: BorderRadius.circular(999),
        ),
      );
}