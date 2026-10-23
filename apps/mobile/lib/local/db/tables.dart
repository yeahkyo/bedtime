import 'package:drift/drift.dart';

/// Cached story rows aligned with API StoryOut (+ sync metadata).
class CachedStories extends Table {
  IntColumn get userId => integer()();
  IntColumn get id => integer()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get language => text().withDefault(const Constant('zh'))();
  TextColumn get theme => text().nullable()();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant(''))();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get softHook => text().nullable()();
  TextColumn get audioUrl => text().nullable()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(5))();
  IntColumn get seriesId => integer().nullable()();
  IntColumn get episodeNo => integer().nullable()();
  IntColumn get childId => integer().nullable()();
  TextColumn get progress => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get voiceName => text().nullable()();
  TextColumn get developmentFocusLabel => text().nullable()();
  TextColumn get storyProvider => text().nullable()();
  TextColumn get speechProvider => text().nullable()();
  TextColumn get speechModel => text().nullable()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId, id};
}

class CachedChildren extends Table {
  IntColumn get userId => integer()();
  IntColumn get id => integer()();
  TextColumn get nickname => text()();
  TextColumn get birthDate => text().nullable()();
  TextColumn get ageBand => text().withDefault(const Constant('3-5'))();
  TextColumn get gender => text().withDefault(const Constant('unspecified'))();
  TextColumn get intro => text().nullable()();
  /// JSON-encoded list of strings.
  TextColumn get interestsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId, id};
}

class CachedCharacters extends Table {
  IntColumn get userId => integer()();
  IntColumn get id => integer()();
  TextColumn get kind => text()();
  TextColumn get name => text()();
  IntColumn get relatedChildId => integer().nullable()();
  TextColumn get relation => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get listenerChildId => integer().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId, id};
}

class CachedVoices extends Table {
  IntColumn get userId => integer()();
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get kind => text().withDefault(const Constant(''))();
  TextColumn get language => text().withDefault(const Constant('zh'))();
  TextColumn get provider => text().withDefault(const Constant(''))();
  TextColumn get providerVoiceId => text().withDefault(const Constant(''))();
  TextColumn get speechModel => text().nullable()();
  TextColumn get speedTier => text().withDefault(const Constant('medium'))();
  RealColumn get speed => real().withDefault(const Constant(1.0))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get previewAudioUrl => text().nullable()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId, id};
}

class CachedVoicePrefs extends Table {
  IntColumn get userId => integer()();
  IntColumn get childId => integer()();
  TextColumn get speedTier => text().withDefault(const Constant('medium'))();
  TextColumn get tonePreset => text().withDefault(const Constant('gentle'))();
  BoolColumn get likenessBoost => boolean().withDefault(const Constant(false))();
  IntColumn get defaultVoiceId => integer().nullable()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId, childId};
}

class AccountSnapshots extends Table {
  IntColumn get userId => integer()();
  TextColumn get displayName => text().nullable()();
  TextColumn get preferredLanguage => text().withDefault(const Constant('zh'))();
  TextColumn get quotaMonth => text().nullable()();
  IntColumn get storyUsed => integer().withDefault(const Constant(0))();
  IntColumn get storyLimit => integer().withDefault(const Constant(0))();
  IntColumn get cloneUsed => integer().withDefault(const Constant(0))();
  IntColumn get cloneLimit => integer().withDefault(const Constant(0))();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId};
}

class MediaFiles extends Table {
  IntColumn get userId => integer()();
  IntColumn get storyId => integer()();
  TextColumn get localPath => text()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();
  BoolColumn get ready => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {userId, storyId};
}

class PlaybackProgress extends Table {
  IntColumn get userId => integer()();
  IntColumn get storyId => integer()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId, storyId};
}

/// Reserved for future favorites feature (no UI this phase).
class StoryFavorites extends Table {
  IntColumn get userId => integer()();
  IntColumn get storyId => integer()();
  DateTimeColumn get favoritedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId, storyId};
}

/// Reserved for future mood calendar (no UI this phase).
class MoodEntries extends Table {
  IntColumn get userId => integer()();
  /// YYYY-MM-DD
  TextColumn get dayKey => text()();
  IntColumn get childId => integer()();
  TextColumn get mood => text().withDefault(const Constant(''))();
  TextColumn get note => text().nullable()();
  IntColumn get storyId => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {userId, dayKey, childId};
}
