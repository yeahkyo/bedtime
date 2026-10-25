import '../api/client.dart';
import 'create_prefs.dart';
import 'db/app_database.dart';
import 'repositories/account_repository.dart';
import 'repositories/character_repository.dart';
import 'repositories/child_repository.dart';
import 'repositories/media_cache.dart';
import 'repositories/playback_repository.dart';
import 'repositories/story_repository.dart';
import 'repositories/voice_repository.dart';
import 'user_scope.dart';

/// App-wide local persistence facade scoped to the active user.
class LocalStore {
  LocalStore._({
    required this.db,
    required this.api,
    required this.userId,
  })  : stories = StoryRepository(db: db, api: api, userId: userId),
        children = ChildRepository(db: db, api: api, userId: userId),
        characters = CharacterRepository(db: db, api: api, userId: userId),
        voices = VoiceRepository(db: db, api: api, userId: userId),
        account = AccountRepository(db: db, api: api, userId: userId),
        media = MediaCache(db: db, api: api, userId: userId),
        playback = PlaybackRepository(db: db, userId: userId);

  final AppDatabase db;
  final ApiClient api;
  final int userId;

  final StoryRepository stories;
  final ChildRepository children;
  final CharacterRepository characters;
  final VoiceRepository voices;
  final AccountRepository account;
  final MediaCache media;
  final PlaybackRepository playback;

  static AppDatabase? _sharedDb;

  static AppDatabase get sharedDb => _sharedDb ??= AppDatabase();

  static Future<LocalStore?> open({
    required ApiClient api,
    int? userId,
  }) async {
    final id = userId ?? await UserScope.load();
    if (id == null || id <= 0) return null;
    return LocalStore._(db: sharedDb, api: api, userId: id);
  }

  static Future<LocalStore> openOrBootstrap({
    required ApiClient api,
    required int userId,
  }) async {
    await UserScope.save(userId);
    return LocalStore._(db: sharedDb, api: api, userId: userId);
  }

  /// Clear DB rows + audio files for this user, then drop scope.
  Future<void> clearForLogout() async {
    await media.clearAllFiles();
    await db.clearUserData(userId);
    await CreatePrefs.clear(userId);
    await UserScope.clear();
  }

  static Future<void> clearActiveUserCache(ApiClient api) async {
    final id = await UserScope.load();
    if (id == null) return;
    final store = LocalStore._(db: sharedDb, api: api, userId: id);
    await store.clearForLogout();
  }
}
