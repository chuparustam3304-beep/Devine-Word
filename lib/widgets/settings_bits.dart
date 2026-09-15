import 'package:flutter/material.dart';

import '../data/models.dart';
import '../design/tokens.dart';
import '../state/app_state.dart';
import '../widgets/dw_svg.dart';

/// Section header (11px, letter-spaced 2.4) positioned for the design space.
Positioned settingsSectionHeader(
  BuildContext context,
  String text, {
  required double top,
}) {
  return Positioned(
    left: 25,
    top: top,
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 2.4,
        fontWeight: FontWeight.w600,
        color: context.dw.section,
      ),
    ),
  );
}

/// The gray rounded panel hosting setting rows.
Positioned settingsPanel(
  BuildContext context, {
  required double top,
  required double height,
  required List<Widget> rows,
}) {
  return Positioned(
    left: 22,
    right: 22,
    top: top,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: context.dw.panel,
        border: Border.all(color: context.dw.hairline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0)
              Divider(height: 1, thickness: 1, color: context.dw.hairline),
            Expanded(child: row),
          ],
        ],
      ),
    ),
  );
}

/// The circled icon at the start of a setting row.
Widget settingsIconCircle(BuildContext context, String asset) {
  return Container(
    width: 36,
    height: 36,
    margin: const EdgeInsets.only(right: 14),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: context.dw.circle,
      border: Border.all(color: context.dw.circleBorder),
    ),
    child: DwSvg(asset, width: 22, height: 22, color: context.dw.ink),
  );
}

/// A tappable row with an optional trailing value and chevron.
Widget settingsNavRow(
  BuildContext context, {
  required String iconAsset,
  required String label,
  String? value,
  VoidCallback? onTap,
}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(11, 0, 14, 0),
      child: Row(
        children: [
          settingsIconCircle(context, iconAsset),
          Text(label, style: TextStyle(fontSize: 14, color: context.dw.ink)),
          const Spacer(),
          if (value != null)
            Text(
              value,
              style: TextStyle(fontSize: 13, color: context.dw.sub),
            ),
          const SizedBox(width: 9),
          DwSvg(
            'assets/08-settings/chevron-right.svg',
            width: 17,
            height: 17,
            color: context.dw.ink,
          ),
        ],
      ),
    ),
  );
}

/// A row whose trailing control is the approved on/off toggle asset.
Widget settingsToggleRow(
  BuildContext context, {
  required String iconAsset,
  required String label,
  String? small,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => onChanged(!value),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(11, 0, 14, 0),
      child: Row(
        children: [
          settingsIconCircle(context, iconAsset),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 14, color: context.dw.ink),
                ),
                if (small != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      small,
                      style: TextStyle(fontSize: 10, color: context.dw.sub),
                    ),
                  ),
              ],
            ),
          ),
          DwSvg(
            value
                ? 'assets/08-settings/toggle-on.svg'
                : 'assets/08-settings/toggle-off.svg',
            width: 44,
            height: 24,
          ),
        ],
      ),
    ),
  );
}

String textSizeLabel(TextSizeOption size) => switch (size) {
  TextSizeOption.small => 'Small',
  TextSizeOption.defaultSize => 'Default',
  TextSizeOption.large => 'Large',
};

/// 570 → "9:30 AM" — 12-hour label for the reminder rows.
String reminderTimeLabel(int minutes) {
  final hour24 = minutes ~/ 60;
  final minute = minutes % 60;
  final period = hour24 < 12 ? 'AM' : 'PM';
  var hour12 = hour24 % 12;
  if (hour12 == 0) hour12 = 12;
  final mm = minute.toString().padLeft(2, '0');
  return '$hour12:$mm $period';
}

/// Opens the OS time picker and persists + reschedules the reminder.
Future<void> chooseReminderTime(BuildContext context, AppState state) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: state.reminderMinutes ~/ 60,
      minute: state.reminderMinutes % 60,
    ),
    helpText: 'Set your daily reminder',
  );
  if (picked != null) {
    await state.setReminderTime(picked.hour * 60 + picked.minute);
  }
}

/// Opens the appearance choice sheet and persists the selection.
Future<void> chooseAppearance(BuildContext context, AppState state) async {
  final mode = await showSettingsChoice<AppearanceMode>(
    context,
    title: 'Appearance',
    options: AppearanceMode.values,
    labelOf: (m) => m.label,
    selected: state.appearanceMode,
  );
  if (mode != null) await state.setAppearance(mode);
}

/// Modal choice sheet for finite persisted options (translation, text size).
Future<T?> showSettingsChoice<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) labelOf,
  required T selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: context.dw.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: Dw.display,
                fontSize: 20,
                color: sheetContext.dw.title,
              ),
            ),
          ),
          for (final option in options)
            ListTile(
              title: Text(labelOf(option)),
              selected: option == selected,
              selectedColor: sheetContext.dw.accent,
              trailing: option == selected
                  ? Icon(Icons.check, color: sheetContext.dw.accent)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(option),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Opens the translation choice sheet and persists the selection.
Future<void> chooseTranslation(BuildContext context, AppState state) async {
  final language = await showSettingsChoice<TranslationLanguage>(
    context,
    title: 'Translation language',
    options: TranslationLanguage.values,
    labelOf: (l) => l.label,
    selected: state.translation,
  );
  if (language != null) await state.setTranslation(language);
}

/// Opens the text-size choice sheet and persists the selection.
Future<void> chooseTextSize(BuildContext context, AppState state) async {
  final size = await showSettingsChoice<TextSizeOption>(
    context,
    title: 'Text size',
    options: TextSizeOption.values,
    labelOf: textSizeLabel,
    selected: state.textSize,
  );
  if (size != null) await state.setTextSize(size);
}
