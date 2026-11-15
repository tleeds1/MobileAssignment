import '../data/db/app_database.dart';
import '../data/repositories/card_repository.dart';
import '../data/repositories/emotion_repository.dart';
import '../data/repositories/schedule_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/story_repository.dart';
import '../services/photo_service.dart';
import '../services/pin_service.dart';
import '../services/tts_service.dart';

/// Gom các phụ thuộc của tầng dữ liệu/dịch vụ để tiêm vào tầng trình bày.
class AppServices {
  AppServices({
    required this.db,
    required this.speech,
    required this.pin,
    PhotoService? photos,
  })  : settingsRepo = SettingsRepository(db),
        scheduleRepo = ScheduleRepository(db),
        cardRepo = CardRepository(db),
        emotionRepo = EmotionRepository(db),
        storyRepo = StoryRepository(db),
        photos = photos ?? PhotoService();

  final AppDatabase db;
  final SpeechService speech;
  final PinService pin;
  final PhotoService photos;
  final SettingsRepository settingsRepo;
  final ScheduleRepository scheduleRepo;
  final CardRepository cardRepo;
  final EmotionRepository emotionRepo;
  final StoryRepository storyRepo;
}
