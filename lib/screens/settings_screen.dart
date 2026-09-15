import 'package:flutter/material.dart';

import '../design/screen_frame.dart';
import '../design/tokens.dart';
import '../widgets/dw_svg.dart';
import '../widgets/settings_bits.dart';
import '../routing/app_router.dart';
import '../state/app_state_scope.dart';

/// Screen 08 — settings. Every row reflects and mutates persisted state.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final dw = context.dw;
    return DwScreenFrame(
      background: dw.background,
      body: (context) => Stack(
        children: [
          Positioned(
            left: 24,
            top: 59,
            width: 149,
            child: DwSvg(
              'assets/08-settings/logo-horizontal.svg',
              color: dw.accent,
            ),
          ),
          Positioned(
            left: 25,
            top: 127,
            child: Text(
              'Settings',
              style: TextStyle(
                fontFamily: Dw.display,
                fontSize: 42,
                height: 1,
                letterSpacing: -0.5,
                color: dw.title,
              ),
            ),
          ),
          Positioned(
            left: 26,
            top: 171,
            child: Text(
              'Make space for your routine.',
              style: TextStyle(fontSize: 15, color: dw.sub),
            ),
          ),
          settingsSectionHeader(context, 'READING', top: 211),
          settingsPanel(
            context,
            top: 233,
            height: 100,
            rows: [
              settingsNavRow(
                context,
                iconAsset: 'assets/08-settings/globe.svg',
                label: 'Translation language',
                value: state.translation.label,
                onTap: () => chooseTranslation(context, state),
              ),
              settingsNavRow(
                context,
                iconAsset: 'assets/08-settings/text-size.svg',
                label: 'Text size',
                value: textSizeLabel(state.textSize),
                onTap: () => chooseTextSize(context, state),
              ),
            ],
          ),
          Positioned(
            left: 26,
            top: 330,
            child: Text(
              'Arabic is always shown.',
              style: TextStyle(fontSize: 11, color: dw.sub),
            ),
          ),
          settingsSectionHeader(context, 'LISTENING', top: 364),
          settingsPanel(
            context,
            top: 386,
            height: 100,
            rows: [
              settingsNavRow(
                context,
                iconAsset: 'assets/08-settings/microphone.svg',
                label: 'Qari',
                value: 'Mishary Alafasy',
                onTap: () => _reciterNote(context),
              ),
              settingsToggleRow(
                context,
                iconAsset: 'assets/08-settings/headphones.svg',
                label: 'Play translation',
                small: 'After Arabic recitation',
                value: state.playTranslationAfterArabic,
                onChanged: state.setPlayTranslationAfterArabic,
              ),
            ],
          ),
          settingsSectionHeader(context, 'PREFERENCES', top: 516),
          // The panel gains a "Reminder time" row (50px) whenever the
          // daily reminder is on.
          settingsPanel(
            context,
            top: 538,
            height: state.dailyReminder ? 199 : 149,
            rows: [
              settingsToggleRow(
                context,
                iconAsset: 'assets/08-settings/bell.svg',
                label: 'Daily reminder',
                value: state.dailyReminder,
                onChanged: state.setDailyReminder,
              ),
              if (state.dailyReminder)
                settingsNavRow(
                  context,
                  iconAsset: 'assets/08-settings/clock.svg',
                  label: 'Reminder time',
                  value: reminderTimeLabel(state.reminderMinutes),
                  onTap: () => chooseReminderTime(context, state),
                ),
              settingsNavRow(
                context,
                iconAsset: 'assets/08-settings/sun.svg',
                label: 'Appearance',
                value: state.appearanceMode.label,
                onTap: () => chooseAppearance(context, state),
              ),
              settingsNavRow(
                context,
                iconAsset: 'assets/08-settings/info.svg',
                label: 'About Devine Word',
                onTap: () => _about(context),
              ),
            ],
          ),
          BottomNavImage(
            asset: 'assets/08-settings/nav.svg',
            onTap: (index) => switchTab(context, index),
          ),
        ],
      ),
    );
  }

  void _reciterNote(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Recitation is currently by Mishary Alafasy. '
          'More reciters arrive with the recitation audio service.',
        ),
      ),
    );
  }

  void _about(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Devine Word',
      applicationVersion: '1.0.0',
      applicationIcon: DwSvg(
        'assets/08-settings/logo-horizontal.svg',
        width: 100,
        color: context.dw.accent,
      ),
      children: const [
        Text(
          'A New Verse Everyday.\n\n'
          'Read, listen, and reflect — anytime, anywhere.',
        ),
      ],
    );
  }
}
