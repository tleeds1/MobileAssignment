import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/models.dart';
import 'services/pin_service.dart';
import 'services/tts_service.dart';
import 'state/app_services.dart';
import 'state/card_controller.dart';
import 'state/caregiver_session.dart';
import 'state/emotion_controller.dart';
import 'state/schedule_controller.dart';
import 'state/settings_controller.dart';
import 'state/story_controller.dart';
import 'ui/child/child_shell.dart';
import 'ui/onboarding_screen.dart';

/// Gắn tầng trạng thái vào cây widget (kiến trúc 3 tầng – Mục 6.2).
class MyLittleDayApp extends StatelessWidget {
  const MyLittleDayApp({
    super.key,
    required this.services,
    required this.initialSettings,
  });

  final AppServices services;
  final AppSettings initialSettings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: services),
        Provider<PinService>.value(value: services.pin),
        ChangeNotifierProvider<SpeechService>.value(value: services.speech),
        ChangeNotifierProvider<SettingsController>(
          create: (_) =>
              SettingsController(services.settingsRepo, initialSettings),
        ),
        ChangeNotifierProvider<CaregiverSession>(
          create: (_) => CaregiverSession(
            timeout:
                Duration(minutes: initialSettings.sessionTimeoutMinutes),
          ),
        ),
        ChangeNotifierProvider<ScheduleController>(
          create: (ctx) => ScheduleController(
              services.scheduleRepo, ctx.read<SettingsController>())
            ..load(),
        ),
        ChangeNotifierProvider<CardController>(
          create: (ctx) => CardController(services.cardRepo,
              ctx.read<SettingsController>(), services.speech)
            ..load(),
        ),
        ChangeNotifierProvider<EmotionController>(
          create: (ctx) {
            final c = EmotionController(
                services.emotionRepo, ctx.read<SettingsController>());
            c.applyRetention().whenComplete(c.load);
            return c;
          },
        ),
        ChangeNotifierProvider<StoryController>(
          create: (_) => StoryController(services.storyRepo)..load(),
        ),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          title: 'My Little Day',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            // Cỡ chữ: tôn trọng cỡ chữ hệ thống và thiết lập trong ứng dụng
            // (NFR-05 – hỗ trợ tối thiểu 130%).
            final mq = MediaQuery.of(context);
            final scale = (mq.textScaleFactor * settings.value.textScale)
                .clamp(1.0, 1.6)
                .toDouble();
            return MediaQuery(
              data: mq.copyWith(
                textScaleFactor: scale,
                disableAnimations:
                    mq.disableAnimations || settings.value.reduceMotion,
              ),
              child: child!,
            );
          },
          home: const _RootGate(),
        ),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final done = context.select<SettingsController, bool>(
        (s) => s.value.onboardingDone);
    return done ? const ChildShell() : const OnboardingScreen();
  }
}
