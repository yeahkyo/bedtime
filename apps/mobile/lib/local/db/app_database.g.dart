// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedStoriesTable extends CachedStories
    with TableInfo<$CachedStoriesTable, CachedStory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedStoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('zh'),
  );
  static const VerificationMeta _themeMeta = const VerificationMeta('theme');
  @override
  late final GeneratedColumn<String> theme = GeneratedColumn<String>(
    'theme',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _softHookMeta = const VerificationMeta(
    'softHook',
  );
  @override
  late final GeneratedColumn<String> softHook = GeneratedColumn<String>(
    'soft_hook',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioUrlMeta = const VerificationMeta(
    'audioUrl',
  );
  @override
  late final GeneratedColumn<String> audioUrl = GeneratedColumn<String>(
    'audio_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
    'duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<int> seriesId = GeneratedColumn<int>(
    'series_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeNoMeta = const VerificationMeta(
    'episodeNo',
  );
  @override
  late final GeneratedColumn<int> episodeNo = GeneratedColumn<int>(
    'episode_no',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<int> childId = GeneratedColumn<int>(
    'child_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<String> progress = GeneratedColumn<String>(
    'progress',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voiceNameMeta = const VerificationMeta(
    'voiceName',
  );
  @override
  late final GeneratedColumn<String> voiceName = GeneratedColumn<String>(
    'voice_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coreMeta = const VerificationMeta('core');
  @override
  late final GeneratedColumn<String> core = GeneratedColumn<String>(
    'core',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _storyProviderMeta = const VerificationMeta(
    'storyProvider',
  );
  @override
  late final GeneratedColumn<String> storyProvider = GeneratedColumn<String>(
    'story_provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speechProviderMeta = const VerificationMeta(
    'speechProvider',
  );
  @override
  late final GeneratedColumn<String> speechProvider = GeneratedColumn<String>(
    'speech_provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speechModelMeta = const VerificationMeta(
    'speechModel',
  );
  @override
  late final GeneratedColumn<String> speechModel = GeneratedColumn<String>(
    'speech_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    id,
    title,
    language,
    theme,
    body,
    status,
    source,
    softHook,
    audioUrl,
    durationMinutes,
    seriesId,
    episodeNo,
    childId,
    progress,
    errorMessage,
    voiceName,
    core,
    storyProvider,
    speechProvider,
    speechModel,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_stories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedStory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('theme')) {
      context.handle(
        _themeMeta,
        theme.isAcceptableOrUnknown(data['theme']!, _themeMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('soft_hook')) {
      context.handle(
        _softHookMeta,
        softHook.isAcceptableOrUnknown(data['soft_hook']!, _softHookMeta),
      );
    }
    if (data.containsKey('audio_url')) {
      context.handle(
        _audioUrlMeta,
        audioUrl.isAcceptableOrUnknown(data['audio_url']!, _audioUrlMeta),
      );
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    }
    if (data.containsKey('episode_no')) {
      context.handle(
        _episodeNoMeta,
        episodeNo.isAcceptableOrUnknown(data['episode_no']!, _episodeNoMeta),
      );
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('voice_name')) {
      context.handle(
        _voiceNameMeta,
        voiceName.isAcceptableOrUnknown(data['voice_name']!, _voiceNameMeta),
      );
    }
    if (data.containsKey('core')) {
      context.handle(
        _coreMeta,
        core.isAcceptableOrUnknown(data['core']!, _coreMeta),
      );
    }
    if (data.containsKey('story_provider')) {
      context.handle(
        _storyProviderMeta,
        storyProvider.isAcceptableOrUnknown(
          data['story_provider']!,
          _storyProviderMeta,
        ),
      );
    }
    if (data.containsKey('speech_provider')) {
      context.handle(
        _speechProviderMeta,
        speechProvider.isAcceptableOrUnknown(
          data['speech_provider']!,
          _speechProviderMeta,
        ),
      );
    }
    if (data.containsKey('speech_model')) {
      context.handle(
        _speechModelMeta,
        speechModel.isAcceptableOrUnknown(
          data['speech_model']!,
          _speechModelMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, id};
  @override
  CachedStory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedStory(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      theme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      softHook: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}soft_hook'],
      ),
      audioUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_url'],
      ),
      durationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_minutes'],
      )!,
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}series_id'],
      ),
      episodeNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_no'],
      ),
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}child_id'],
      ),
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}progress'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      voiceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_name'],
      ),
      core: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}core'],
      ),
      storyProvider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}story_provider'],
      ),
      speechProvider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speech_provider'],
      ),
      speechModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speech_model'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $CachedStoriesTable createAlias(String alias) {
    return $CachedStoriesTable(attachedDatabase, alias);
  }
}

class CachedStory extends DataClass implements Insertable<CachedStory> {
  final int userId;
  final int id;
  final String title;
  final String language;
  final String? theme;
  final String body;
  final String status;
  final String source;
  final String? softHook;
  final String? audioUrl;
  final int durationMinutes;
  final int? seriesId;
  final int? episodeNo;
  final int? childId;
  final String? progress;
  final String? errorMessage;
  final String? voiceName;
  final String? core;
  final String? storyProvider;
  final String? speechProvider;
  final String? speechModel;
  final DateTime syncedAt;
  const CachedStory({
    required this.userId,
    required this.id,
    required this.title,
    required this.language,
    this.theme,
    required this.body,
    required this.status,
    required this.source,
    this.softHook,
    this.audioUrl,
    required this.durationMinutes,
    this.seriesId,
    this.episodeNo,
    this.childId,
    this.progress,
    this.errorMessage,
    this.voiceName,
    this.core,
    this.storyProvider,
    this.speechProvider,
    this.speechModel,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<int>(userId);
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['language'] = Variable<String>(language);
    if (!nullToAbsent || theme != null) {
      map['theme'] = Variable<String>(theme);
    }
    map['body'] = Variable<String>(body);
    map['status'] = Variable<String>(status);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || softHook != null) {
      map['soft_hook'] = Variable<String>(softHook);
    }
    if (!nullToAbsent || audioUrl != null) {
      map['audio_url'] = Variable<String>(audioUrl);
    }
    map['duration_minutes'] = Variable<int>(durationMinutes);
    if (!nullToAbsent || seriesId != null) {
      map['series_id'] = Variable<int>(seriesId);
    }
    if (!nullToAbsent || episodeNo != null) {
      map['episode_no'] = Variable<int>(episodeNo);
    }
    if (!nullToAbsent || childId != null) {
      map['child_id'] = Variable<int>(childId);
    }
    if (!nullToAbsent || progress != null) {
      map['progress'] = Variable<String>(progress);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || voiceName != null) {
      map['voice_name'] = Variable<String>(voiceName);
    }
    if (!nullToAbsent || core != null) {
      map['core'] = Variable<String>(core);
    }
    if (!nullToAbsent || storyProvider != null) {
      map['story_provider'] = Variable<String>(storyProvider);
    }
    if (!nullToAbsent || speechProvider != null) {
      map['speech_provider'] = Variable<String>(speechProvider);
    }
    if (!nullToAbsent || speechModel != null) {
      map['speech_model'] = Variable<String>(speechModel);
    }
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  CachedStoriesCompanion toCompanion(bool nullToAbsent) {
    return CachedStoriesCompanion(
      userId: Value(userId),
      id: Value(id),
      title: Value(title),
      language: Value(language),
      theme: theme == null && nullToAbsent
          ? const Value.absent()
          : Value(theme),
      body: Value(body),
      status: Value(status),
      source: Value(source),
      softHook: softHook == null && nullToAbsent
          ? const Value.absent()
          : Value(softHook),
      audioUrl: audioUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(audioUrl),
      durationMinutes: Value(durationMinutes),
      seriesId: seriesId == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesId),
      episodeNo: episodeNo == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeNo),
      childId: childId == null && nullToAbsent
          ? const Value.absent()
          : Value(childId),
      progress: progress == null && nullToAbsent
          ? const Value.absent()
          : Value(progress),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      voiceName: voiceName == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceName),
      core: core == null && nullToAbsent ? const Value.absent() : Value(core),
      storyProvider: storyProvider == null && nullToAbsent
          ? const Value.absent()
          : Value(storyProvider),
      speechProvider: speechProvider == null && nullToAbsent
          ? const Value.absent()
          : Value(speechProvider),
      speechModel: speechModel == null && nullToAbsent
          ? const Value.absent()
          : Value(speechModel),
      syncedAt: Value(syncedAt),
    );
  }

  factory CachedStory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedStory(
      userId: serializer.fromJson<int>(json['userId']),
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      language: serializer.fromJson<String>(json['language']),
      theme: serializer.fromJson<String?>(json['theme']),
      body: serializer.fromJson<String>(json['body']),
      status: serializer.fromJson<String>(json['status']),
      source: serializer.fromJson<String>(json['source']),
      softHook: serializer.fromJson<String?>(json['softHook']),
      audioUrl: serializer.fromJson<String?>(json['audioUrl']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
      seriesId: serializer.fromJson<int?>(json['seriesId']),
      episodeNo: serializer.fromJson<int?>(json['episodeNo']),
      childId: serializer.fromJson<int?>(json['childId']),
      progress: serializer.fromJson<String?>(json['progress']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      voiceName: serializer.fromJson<String?>(json['voiceName']),
      core: serializer.fromJson<String?>(json['core']),
      storyProvider: serializer.fromJson<String?>(json['storyProvider']),
      speechProvider: serializer.fromJson<String?>(json['speechProvider']),
      speechModel: serializer.fromJson<String?>(json['speechModel']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<int>(userId),
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'language': serializer.toJson<String>(language),
      'theme': serializer.toJson<String?>(theme),
      'body': serializer.toJson<String>(body),
      'status': serializer.toJson<String>(status),
      'source': serializer.toJson<String>(source),
      'softHook': serializer.toJson<String?>(softHook),
      'audioUrl': serializer.toJson<String?>(audioUrl),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
      'seriesId': serializer.toJson<int?>(seriesId),
      'episodeNo': serializer.toJson<int?>(episodeNo),
      'childId': serializer.toJson<int?>(childId),
      'progress': serializer.toJson<String?>(progress),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'voiceName': serializer.toJson<String?>(voiceName),
      'core': serializer.toJson<String?>(core),
      'storyProvider': serializer.toJson<String?>(storyProvider),
      'speechProvider': serializer.toJson<String?>(speechProvider),
      'speechModel': serializer.toJson<String?>(speechModel),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  CachedStory copyWith({
    int? userId,
    int? id,
    String? title,
    String? language,
    Value<String?> theme = const Value.absent(),
    String? body,
    String? status,
    String? source,
    Value<String?> softHook = const Value.absent(),
    Value<String?> audioUrl = const Value.absent(),
    int? durationMinutes,
    Value<int?> seriesId = const Value.absent(),
    Value<int?> episodeNo = const Value.absent(),
    Value<int?> childId = const Value.absent(),
    Value<String?> progress = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    Value<String?> voiceName = const Value.absent(),
    Value<String?> core = const Value.absent(),
    Value<String?> storyProvider = const Value.absent(),
    Value<String?> speechProvider = const Value.absent(),
    Value<String?> speechModel = const Value.absent(),
    DateTime? syncedAt,
  }) => CachedStory(
    userId: userId ?? this.userId,
    id: id ?? this.id,
    title: title ?? this.title,
    language: language ?? this.language,
    theme: theme.present ? theme.value : this.theme,
    body: body ?? this.body,
    status: status ?? this.status,
    source: source ?? this.source,
    softHook: softHook.present ? softHook.value : this.softHook,
    audioUrl: audioUrl.present ? audioUrl.value : this.audioUrl,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    seriesId: seriesId.present ? seriesId.value : this.seriesId,
    episodeNo: episodeNo.present ? episodeNo.value : this.episodeNo,
    childId: childId.present ? childId.value : this.childId,
    progress: progress.present ? progress.value : this.progress,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    voiceName: voiceName.present ? voiceName.value : this.voiceName,
    core: core.present ? core.value : this.core,
    storyProvider: storyProvider.present
        ? storyProvider.value
        : this.storyProvider,
    speechProvider: speechProvider.present
        ? speechProvider.value
        : this.speechProvider,
    speechModel: speechModel.present ? speechModel.value : this.speechModel,
    syncedAt: syncedAt ?? this.syncedAt,
  );
  CachedStory copyWithCompanion(CachedStoriesCompanion data) {
    return CachedStory(
      userId: data.userId.present ? data.userId.value : this.userId,
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      language: data.language.present ? data.language.value : this.language,
      theme: data.theme.present ? data.theme.value : this.theme,
      body: data.body.present ? data.body.value : this.body,
      status: data.status.present ? data.status.value : this.status,
      source: data.source.present ? data.source.value : this.source,
      softHook: data.softHook.present ? data.softHook.value : this.softHook,
      audioUrl: data.audioUrl.present ? data.audioUrl.value : this.audioUrl,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      episodeNo: data.episodeNo.present ? data.episodeNo.value : this.episodeNo,
      childId: data.childId.present ? data.childId.value : this.childId,
      progress: data.progress.present ? data.progress.value : this.progress,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      voiceName: data.voiceName.present ? data.voiceName.value : this.voiceName,
      core: data.core.present ? data.core.value : this.core,
      storyProvider: data.storyProvider.present
          ? data.storyProvider.value
          : this.storyProvider,
      speechProvider: data.speechProvider.present
          ? data.speechProvider.value
          : this.speechProvider,
      speechModel: data.speechModel.present
          ? data.speechModel.value
          : this.speechModel,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedStory(')
          ..write('userId: $userId, ')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('language: $language, ')
          ..write('theme: $theme, ')
          ..write('body: $body, ')
          ..write('status: $status, ')
          ..write('source: $source, ')
          ..write('softHook: $softHook, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('seriesId: $seriesId, ')
          ..write('episodeNo: $episodeNo, ')
          ..write('childId: $childId, ')
          ..write('progress: $progress, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('voiceName: $voiceName, ')
          ..write('core: $core, ')
          ..write('storyProvider: $storyProvider, ')
          ..write('speechProvider: $speechProvider, ')
          ..write('speechModel: $speechModel, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    userId,
    id,
    title,
    language,
    theme,
    body,
    status,
    source,
    softHook,
    audioUrl,
    durationMinutes,
    seriesId,
    episodeNo,
    childId,
    progress,
    errorMessage,
    voiceName,
    core,
    storyProvider,
    speechProvider,
    speechModel,
    syncedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedStory &&
          other.userId == this.userId &&
          other.id == this.id &&
          other.title == this.title &&
          other.language == this.language &&
          other.theme == this.theme &&
          other.body == this.body &&
          other.status == this.status &&
          other.source == this.source &&
          other.softHook == this.softHook &&
          other.audioUrl == this.audioUrl &&
          other.durationMinutes == this.durationMinutes &&
          other.seriesId == this.seriesId &&
          other.episodeNo == this.episodeNo &&
          other.childId == this.childId &&
          other.progress == this.progress &&
          other.errorMessage == this.errorMessage &&
          other.voiceName == this.voiceName &&
          other.core == this.core &&
          other.storyProvider == this.storyProvider &&
          other.speechProvider == this.speechProvider &&
          other.speechModel == this.speechModel &&
          other.syncedAt == this.syncedAt);
}

class CachedStoriesCompanion extends UpdateCompanion<CachedStory> {
  final Value<int> userId;
  final Value<int> id;
  final Value<String> title;
  final Value<String> language;
  final Value<String?> theme;
  final Value<String> body;
  final Value<String> status;
  final Value<String> source;
  final Value<String?> softHook;
  final Value<String?> audioUrl;
  final Value<int> durationMinutes;
  final Value<int?> seriesId;
  final Value<int?> episodeNo;
  final Value<int?> childId;
  final Value<String?> progress;
  final Value<String?> errorMessage;
  final Value<String?> voiceName;
  final Value<String?> core;
  final Value<String?> storyProvider;
  final Value<String?> speechProvider;
  final Value<String?> speechModel;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const CachedStoriesCompanion({
    this.userId = const Value.absent(),
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.language = const Value.absent(),
    this.theme = const Value.absent(),
    this.body = const Value.absent(),
    this.status = const Value.absent(),
    this.source = const Value.absent(),
    this.softHook = const Value.absent(),
    this.audioUrl = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.episodeNo = const Value.absent(),
    this.childId = const Value.absent(),
    this.progress = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.voiceName = const Value.absent(),
    this.core = const Value.absent(),
    this.storyProvider = const Value.absent(),
    this.speechProvider = const Value.absent(),
    this.speechModel = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedStoriesCompanion.insert({
    required int userId,
    required int id,
    this.title = const Value.absent(),
    this.language = const Value.absent(),
    this.theme = const Value.absent(),
    this.body = const Value.absent(),
    this.status = const Value.absent(),
    this.source = const Value.absent(),
    this.softHook = const Value.absent(),
    this.audioUrl = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.episodeNo = const Value.absent(),
    this.childId = const Value.absent(),
    this.progress = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.voiceName = const Value.absent(),
    this.core = const Value.absent(),
    this.storyProvider = const Value.absent(),
    this.speechProvider = const Value.absent(),
    this.speechModel = const Value.absent(),
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       id = Value(id),
       syncedAt = Value(syncedAt);
  static Insertable<CachedStory> custom({
    Expression<int>? userId,
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? language,
    Expression<String>? theme,
    Expression<String>? body,
    Expression<String>? status,
    Expression<String>? source,
    Expression<String>? softHook,
    Expression<String>? audioUrl,
    Expression<int>? durationMinutes,
    Expression<int>? seriesId,
    Expression<int>? episodeNo,
    Expression<int>? childId,
    Expression<String>? progress,
    Expression<String>? errorMessage,
    Expression<String>? voiceName,
    Expression<String>? core,
    Expression<String>? storyProvider,
    Expression<String>? speechProvider,
    Expression<String>? speechModel,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (language != null) 'language': language,
      if (theme != null) 'theme': theme,
      if (body != null) 'body': body,
      if (status != null) 'status': status,
      if (source != null) 'source': source,
      if (softHook != null) 'soft_hook': softHook,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (seriesId != null) 'series_id': seriesId,
      if (episodeNo != null) 'episode_no': episodeNo,
      if (childId != null) 'child_id': childId,
      if (progress != null) 'progress': progress,
      if (errorMessage != null) 'error_message': errorMessage,
      if (voiceName != null) 'voice_name': voiceName,
      if (core != null) 'core': core,
      if (storyProvider != null) 'story_provider': storyProvider,
      if (speechProvider != null) 'speech_provider': speechProvider,
      if (speechModel != null) 'speech_model': speechModel,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedStoriesCompanion copyWith({
    Value<int>? userId,
    Value<int>? id,
    Value<String>? title,
    Value<String>? language,
    Value<String?>? theme,
    Value<String>? body,
    Value<String>? status,
    Value<String>? source,
    Value<String?>? softHook,
    Value<String?>? audioUrl,
    Value<int>? durationMinutes,
    Value<int?>? seriesId,
    Value<int?>? episodeNo,
    Value<int?>? childId,
    Value<String?>? progress,
    Value<String?>? errorMessage,
    Value<String?>? voiceName,
    Value<String?>? core,
    Value<String?>? storyProvider,
    Value<String?>? speechProvider,
    Value<String?>? speechModel,
    Value<DateTime>? syncedAt,
    Value<int>? rowid,
  }) {
    return CachedStoriesCompanion(
      userId: userId ?? this.userId,
      id: id ?? this.id,
      title: title ?? this.title,
      language: language ?? this.language,
      theme: theme ?? this.theme,
      body: body ?? this.body,
      status: status ?? this.status,
      source: source ?? this.source,
      softHook: softHook ?? this.softHook,
      audioUrl: audioUrl ?? this.audioUrl,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      seriesId: seriesId ?? this.seriesId,
      episodeNo: episodeNo ?? this.episodeNo,
      childId: childId ?? this.childId,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      voiceName: voiceName ?? this.voiceName,
      core: core ?? this.core,
      storyProvider: storyProvider ?? this.storyProvider,
      speechProvider: speechProvider ?? this.speechProvider,
      speechModel: speechModel ?? this.speechModel,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (theme.present) {
      map['theme'] = Variable<String>(theme.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (softHook.present) {
      map['soft_hook'] = Variable<String>(softHook.value);
    }
    if (audioUrl.present) {
      map['audio_url'] = Variable<String>(audioUrl.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<int>(seriesId.value);
    }
    if (episodeNo.present) {
      map['episode_no'] = Variable<int>(episodeNo.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<int>(childId.value);
    }
    if (progress.present) {
      map['progress'] = Variable<String>(progress.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (voiceName.present) {
      map['voice_name'] = Variable<String>(voiceName.value);
    }
    if (core.present) {
      map['core'] = Variable<String>(core.value);
    }
    if (storyProvider.present) {
      map['story_provider'] = Variable<String>(storyProvider.value);
    }
    if (speechProvider.present) {
      map['speech_provider'] = Variable<String>(speechProvider.value);
    }
    if (speechModel.present) {
      map['speech_model'] = Variable<String>(speechModel.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedStoriesCompanion(')
          ..write('userId: $userId, ')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('language: $language, ')
          ..write('theme: $theme, ')
          ..write('body: $body, ')
          ..write('status: $status, ')
          ..write('source: $source, ')
          ..write('softHook: $softHook, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('seriesId: $seriesId, ')
          ..write('episodeNo: $episodeNo, ')
          ..write('childId: $childId, ')
          ..write('progress: $progress, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('voiceName: $voiceName, ')
          ..write('core: $core, ')
          ..write('storyProvider: $storyProvider, ')
          ..write('speechProvider: $speechProvider, ')
          ..write('speechModel: $speechModel, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedChildrenTable extends CachedChildren
    with TableInfo<$CachedChildrenTable, CachedChildrenData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedChildrenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _birthDateMeta = const VerificationMeta(
    'birthDate',
  );
  @override
  late final GeneratedColumn<String> birthDate = GeneratedColumn<String>(
    'birth_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ageBandMeta = const VerificationMeta(
    'ageBand',
  );
  @override
  late final GeneratedColumn<String> ageBand = GeneratedColumn<String>(
    'age_band',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('3-5'),
  );
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
    'gender',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unspecified'),
  );
  static const VerificationMeta _introMeta = const VerificationMeta('intro');
  @override
  late final GeneratedColumn<String> intro = GeneratedColumn<String>(
    'intro',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _interestsJsonMeta = const VerificationMeta(
    'interestsJson',
  );
  @override
  late final GeneratedColumn<String> interestsJson = GeneratedColumn<String>(
    'interests_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    id,
    nickname,
    birthDate,
    ageBand,
    gender,
    intro,
    interestsJson,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_children';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedChildrenData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    } else if (isInserting) {
      context.missing(_nicknameMeta);
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
      );
    }
    if (data.containsKey('age_band')) {
      context.handle(
        _ageBandMeta,
        ageBand.isAcceptableOrUnknown(data['age_band']!, _ageBandMeta),
      );
    }
    if (data.containsKey('gender')) {
      context.handle(
        _genderMeta,
        gender.isAcceptableOrUnknown(data['gender']!, _genderMeta),
      );
    }
    if (data.containsKey('intro')) {
      context.handle(
        _introMeta,
        intro.isAcceptableOrUnknown(data['intro']!, _introMeta),
      );
    }
    if (data.containsKey('interests_json')) {
      context.handle(
        _interestsJsonMeta,
        interestsJson.isAcceptableOrUnknown(
          data['interests_json']!,
          _interestsJsonMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, id};
  @override
  CachedChildrenData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedChildrenData(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      )!,
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}birth_date'],
      ),
      ageBand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}age_band'],
      )!,
      gender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gender'],
      )!,
      intro: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intro'],
      ),
      interestsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}interests_json'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $CachedChildrenTable createAlias(String alias) {
    return $CachedChildrenTable(attachedDatabase, alias);
  }
}

class CachedChildrenData extends DataClass
    implements Insertable<CachedChildrenData> {
  final int userId;
  final int id;
  final String nickname;
  final String? birthDate;
  final String ageBand;
  final String gender;
  final String? intro;

  /// JSON-encoded list of strings.
  final String interestsJson;
  final DateTime syncedAt;
  const CachedChildrenData({
    required this.userId,
    required this.id,
    required this.nickname,
    this.birthDate,
    required this.ageBand,
    required this.gender,
    this.intro,
    required this.interestsJson,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<int>(userId);
    map['id'] = Variable<int>(id);
    map['nickname'] = Variable<String>(nickname);
    if (!nullToAbsent || birthDate != null) {
      map['birth_date'] = Variable<String>(birthDate);
    }
    map['age_band'] = Variable<String>(ageBand);
    map['gender'] = Variable<String>(gender);
    if (!nullToAbsent || intro != null) {
      map['intro'] = Variable<String>(intro);
    }
    map['interests_json'] = Variable<String>(interestsJson);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  CachedChildrenCompanion toCompanion(bool nullToAbsent) {
    return CachedChildrenCompanion(
      userId: Value(userId),
      id: Value(id),
      nickname: Value(nickname),
      birthDate: birthDate == null && nullToAbsent
          ? const Value.absent()
          : Value(birthDate),
      ageBand: Value(ageBand),
      gender: Value(gender),
      intro: intro == null && nullToAbsent
          ? const Value.absent()
          : Value(intro),
      interestsJson: Value(interestsJson),
      syncedAt: Value(syncedAt),
    );
  }

  factory CachedChildrenData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedChildrenData(
      userId: serializer.fromJson<int>(json['userId']),
      id: serializer.fromJson<int>(json['id']),
      nickname: serializer.fromJson<String>(json['nickname']),
      birthDate: serializer.fromJson<String?>(json['birthDate']),
      ageBand: serializer.fromJson<String>(json['ageBand']),
      gender: serializer.fromJson<String>(json['gender']),
      intro: serializer.fromJson<String?>(json['intro']),
      interestsJson: serializer.fromJson<String>(json['interestsJson']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<int>(userId),
      'id': serializer.toJson<int>(id),
      'nickname': serializer.toJson<String>(nickname),
      'birthDate': serializer.toJson<String?>(birthDate),
      'ageBand': serializer.toJson<String>(ageBand),
      'gender': serializer.toJson<String>(gender),
      'intro': serializer.toJson<String?>(intro),
      'interestsJson': serializer.toJson<String>(interestsJson),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  CachedChildrenData copyWith({
    int? userId,
    int? id,
    String? nickname,
    Value<String?> birthDate = const Value.absent(),
    String? ageBand,
    String? gender,
    Value<String?> intro = const Value.absent(),
    String? interestsJson,
    DateTime? syncedAt,
  }) => CachedChildrenData(
    userId: userId ?? this.userId,
    id: id ?? this.id,
    nickname: nickname ?? this.nickname,
    birthDate: birthDate.present ? birthDate.value : this.birthDate,
    ageBand: ageBand ?? this.ageBand,
    gender: gender ?? this.gender,
    intro: intro.present ? intro.value : this.intro,
    interestsJson: interestsJson ?? this.interestsJson,
    syncedAt: syncedAt ?? this.syncedAt,
  );
  CachedChildrenData copyWithCompanion(CachedChildrenCompanion data) {
    return CachedChildrenData(
      userId: data.userId.present ? data.userId.value : this.userId,
      id: data.id.present ? data.id.value : this.id,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      ageBand: data.ageBand.present ? data.ageBand.value : this.ageBand,
      gender: data.gender.present ? data.gender.value : this.gender,
      intro: data.intro.present ? data.intro.value : this.intro,
      interestsJson: data.interestsJson.present
          ? data.interestsJson.value
          : this.interestsJson,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedChildrenData(')
          ..write('userId: $userId, ')
          ..write('id: $id, ')
          ..write('nickname: $nickname, ')
          ..write('birthDate: $birthDate, ')
          ..write('ageBand: $ageBand, ')
          ..write('gender: $gender, ')
          ..write('intro: $intro, ')
          ..write('interestsJson: $interestsJson, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    id,
    nickname,
    birthDate,
    ageBand,
    gender,
    intro,
    interestsJson,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedChildrenData &&
          other.userId == this.userId &&
          other.id == this.id &&
          other.nickname == this.nickname &&
          other.birthDate == this.birthDate &&
          other.ageBand == this.ageBand &&
          other.gender == this.gender &&
          other.intro == this.intro &&
          other.interestsJson == this.interestsJson &&
          other.syncedAt == this.syncedAt);
}

class CachedChildrenCompanion extends UpdateCompanion<CachedChildrenData> {
  final Value<int> userId;
  final Value<int> id;
  final Value<String> nickname;
  final Value<String?> birthDate;
  final Value<String> ageBand;
  final Value<String> gender;
  final Value<String?> intro;
  final Value<String> interestsJson;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const CachedChildrenCompanion({
    this.userId = const Value.absent(),
    this.id = const Value.absent(),
    this.nickname = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.ageBand = const Value.absent(),
    this.gender = const Value.absent(),
    this.intro = const Value.absent(),
    this.interestsJson = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedChildrenCompanion.insert({
    required int userId,
    required int id,
    required String nickname,
    this.birthDate = const Value.absent(),
    this.ageBand = const Value.absent(),
    this.gender = const Value.absent(),
    this.intro = const Value.absent(),
    this.interestsJson = const Value.absent(),
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       id = Value(id),
       nickname = Value(nickname),
       syncedAt = Value(syncedAt);
  static Insertable<CachedChildrenData> custom({
    Expression<int>? userId,
    Expression<int>? id,
    Expression<String>? nickname,
    Expression<String>? birthDate,
    Expression<String>? ageBand,
    Expression<String>? gender,
    Expression<String>? intro,
    Expression<String>? interestsJson,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (id != null) 'id': id,
      if (nickname != null) 'nickname': nickname,
      if (birthDate != null) 'birth_date': birthDate,
      if (ageBand != null) 'age_band': ageBand,
      if (gender != null) 'gender': gender,
      if (intro != null) 'intro': intro,
      if (interestsJson != null) 'interests_json': interestsJson,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedChildrenCompanion copyWith({
    Value<int>? userId,
    Value<int>? id,
    Value<String>? nickname,
    Value<String?>? birthDate,
    Value<String>? ageBand,
    Value<String>? gender,
    Value<String?>? intro,
    Value<String>? interestsJson,
    Value<DateTime>? syncedAt,
    Value<int>? rowid,
  }) {
    return CachedChildrenCompanion(
      userId: userId ?? this.userId,
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      birthDate: birthDate ?? this.birthDate,
      ageBand: ageBand ?? this.ageBand,
      gender: gender ?? this.gender,
      intro: intro ?? this.intro,
      interestsJson: interestsJson ?? this.interestsJson,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<String>(birthDate.value);
    }
    if (ageBand.present) {
      map['age_band'] = Variable<String>(ageBand.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (intro.present) {
      map['intro'] = Variable<String>(intro.value);
    }
    if (interestsJson.present) {
      map['interests_json'] = Variable<String>(interestsJson.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedChildrenCompanion(')
          ..write('userId: $userId, ')
          ..write('id: $id, ')
          ..write('nickname: $nickname, ')
          ..write('birthDate: $birthDate, ')
          ..write('ageBand: $ageBand, ')
          ..write('gender: $gender, ')
          ..write('intro: $intro, ')
          ..write('interestsJson: $interestsJson, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedCharactersTable extends CachedCharacters
    with TableInfo<$CachedCharactersTable, CachedCharacter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCharactersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relatedChildIdMeta = const VerificationMeta(
    'relatedChildId',
  );
  @override
  late final GeneratedColumn<int> relatedChildId = GeneratedColumn<int>(
    'related_child_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _relationMeta = const VerificationMeta(
    'relation',
  );
  @override
  late final GeneratedColumn<String> relation = GeneratedColumn<String>(
    'relation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _listenerChildIdMeta = const VerificationMeta(
    'listenerChildId',
  );
  @override
  late final GeneratedColumn<int> listenerChildId = GeneratedColumn<int>(
    'listener_child_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    id,
    kind,
    name,
    relatedChildId,
    relation,
    note,
    listenerChildId,
    enabled,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_characters';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedCharacter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('related_child_id')) {
      context.handle(
        _relatedChildIdMeta,
        relatedChildId.isAcceptableOrUnknown(
          data['related_child_id']!,
          _relatedChildIdMeta,
        ),
      );
    }
    if (data.containsKey('relation')) {
      context.handle(
        _relationMeta,
        relation.isAcceptableOrUnknown(data['relation']!, _relationMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('listener_child_id')) {
      context.handle(
        _listenerChildIdMeta,
        listenerChildId.isAcceptableOrUnknown(
          data['listener_child_id']!,
          _listenerChildIdMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, id};
  @override
  CachedCharacter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCharacter(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      relatedChildId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}related_child_id'],
      ),
      relation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relation'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      listenerChildId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}listener_child_id'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $CachedCharactersTable createAlias(String alias) {
    return $CachedCharactersTable(attachedDatabase, alias);
  }
}

class CachedCharacter extends DataClass implements Insertable<CachedCharacter> {
  final int userId;
  final int id;
  final String kind;
  final String name;
  final int? relatedChildId;
  final String? relation;
  final String? note;
  final int? listenerChildId;
  final bool enabled;
  final DateTime syncedAt;
  const CachedCharacter({
    required this.userId,
    required this.id,
    required this.kind,
    required this.name,
    this.relatedChildId,
    this.relation,
    this.note,
    this.listenerChildId,
    required this.enabled,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<int>(userId);
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || relatedChildId != null) {
      map['related_child_id'] = Variable<int>(relatedChildId);
    }
    if (!nullToAbsent || relation != null) {
      map['relation'] = Variable<String>(relation);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || listenerChildId != null) {
      map['listener_child_id'] = Variable<int>(listenerChildId);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  CachedCharactersCompanion toCompanion(bool nullToAbsent) {
    return CachedCharactersCompanion(
      userId: Value(userId),
      id: Value(id),
      kind: Value(kind),
      name: Value(name),
      relatedChildId: relatedChildId == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedChildId),
      relation: relation == null && nullToAbsent
          ? const Value.absent()
          : Value(relation),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      listenerChildId: listenerChildId == null && nullToAbsent
          ? const Value.absent()
          : Value(listenerChildId),
      enabled: Value(enabled),
      syncedAt: Value(syncedAt),
    );
  }

  factory CachedCharacter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCharacter(
      userId: serializer.fromJson<int>(json['userId']),
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      relatedChildId: serializer.fromJson<int?>(json['relatedChildId']),
      relation: serializer.fromJson<String?>(json['relation']),
      note: serializer.fromJson<String?>(json['note']),
      listenerChildId: serializer.fromJson<int?>(json['listenerChildId']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<int>(userId),
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'relatedChildId': serializer.toJson<int?>(relatedChildId),
      'relation': serializer.toJson<String?>(relation),
      'note': serializer.toJson<String?>(note),
      'listenerChildId': serializer.toJson<int?>(listenerChildId),
      'enabled': serializer.toJson<bool>(enabled),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  CachedCharacter copyWith({
    int? userId,
    int? id,
    String? kind,
    String? name,
    Value<int?> relatedChildId = const Value.absent(),
    Value<String?> relation = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<int?> listenerChildId = const Value.absent(),
    bool? enabled,
    DateTime? syncedAt,
  }) => CachedCharacter(
    userId: userId ?? this.userId,
    id: id ?? this.id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    relatedChildId: relatedChildId.present
        ? relatedChildId.value
        : this.relatedChildId,
    relation: relation.present ? relation.value : this.relation,
    note: note.present ? note.value : this.note,
    listenerChildId: listenerChildId.present
        ? listenerChildId.value
        : this.listenerChildId,
    enabled: enabled ?? this.enabled,
    syncedAt: syncedAt ?? this.syncedAt,
  );
  CachedCharacter copyWithCompanion(CachedCharactersCompanion data) {
    return CachedCharacter(
      userId: data.userId.present ? data.userId.value : this.userId,
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      relatedChildId: data.relatedChildId.present
          ? data.relatedChildId.value
          : this.relatedChildId,
      relation: data.relation.present ? data.relation.value : this.relation,
      note: data.note.present ? data.note.value : this.note,
      listenerChildId: data.listenerChildId.present
          ? data.listenerChildId.value
          : this.listenerChildId,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCharacter(')
          ..write('userId: $userId, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('relatedChildId: $relatedChildId, ')
          ..write('relation: $relation, ')
          ..write('note: $note, ')
          ..write('listenerChildId: $listenerChildId, ')
          ..write('enabled: $enabled, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    id,
    kind,
    name,
    relatedChildId,
    relation,
    note,
    listenerChildId,
    enabled,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCharacter &&
          other.userId == this.userId &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.relatedChildId == this.relatedChildId &&
          other.relation == this.relation &&
          other.note == this.note &&
          other.listenerChildId == this.listenerChildId &&
          other.enabled == this.enabled &&
          other.syncedAt == this.syncedAt);
}

class CachedCharactersCompanion extends UpdateCompanion<CachedCharacter> {
  final Value<int> userId;
  final Value<int> id;
  final Value<String> kind;
  final Value<String> name;
  final Value<int?> relatedChildId;
  final Value<String?> relation;
  final Value<String?> note;
  final Value<int?> listenerChildId;
  final Value<bool> enabled;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const CachedCharactersCompanion({
    this.userId = const Value.absent(),
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.relatedChildId = const Value.absent(),
    this.relation = const Value.absent(),
    this.note = const Value.absent(),
    this.listenerChildId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedCharactersCompanion.insert({
    required int userId,
    required int id,
    required String kind,
    required String name,
    this.relatedChildId = const Value.absent(),
    this.relation = const Value.absent(),
    this.note = const Value.absent(),
    this.listenerChildId = const Value.absent(),
    this.enabled = const Value.absent(),
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       id = Value(id),
       kind = Value(kind),
       name = Value(name),
       syncedAt = Value(syncedAt);
  static Insertable<CachedCharacter> custom({
    Expression<int>? userId,
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<int>? relatedChildId,
    Expression<String>? relation,
    Expression<String>? note,
    Expression<int>? listenerChildId,
    Expression<bool>? enabled,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (relatedChildId != null) 'related_child_id': relatedChildId,
      if (relation != null) 'relation': relation,
      if (note != null) 'note': note,
      if (listenerChildId != null) 'listener_child_id': listenerChildId,
      if (enabled != null) 'enabled': enabled,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedCharactersCompanion copyWith({
    Value<int>? userId,
    Value<int>? id,
    Value<String>? kind,
    Value<String>? name,
    Value<int?>? relatedChildId,
    Value<String?>? relation,
    Value<String?>? note,
    Value<int?>? listenerChildId,
    Value<bool>? enabled,
    Value<DateTime>? syncedAt,
    Value<int>? rowid,
  }) {
    return CachedCharactersCompanion(
      userId: userId ?? this.userId,
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      relatedChildId: relatedChildId ?? this.relatedChildId,
      relation: relation ?? this.relation,
      note: note ?? this.note,
      listenerChildId: listenerChildId ?? this.listenerChildId,
      enabled: enabled ?? this.enabled,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (relatedChildId.present) {
      map['related_child_id'] = Variable<int>(relatedChildId.value);
    }
    if (relation.present) {
      map['relation'] = Variable<String>(relation.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (listenerChildId.present) {
      map['listener_child_id'] = Variable<int>(listenerChildId.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCharactersCompanion(')
          ..write('userId: $userId, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('relatedChildId: $relatedChildId, ')
          ..write('relation: $relation, ')
          ..write('note: $note, ')
          ..write('listenerChildId: $listenerChildId, ')
          ..write('enabled: $enabled, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedVoicesTable extends CachedVoices
    with TableInfo<$CachedVoicesTable, CachedVoice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedVoicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('zh'),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _providerVoiceIdMeta = const VerificationMeta(
    'providerVoiceId',
  );
  @override
  late final GeneratedColumn<String> providerVoiceId = GeneratedColumn<String>(
    'provider_voice_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _speechModelMeta = const VerificationMeta(
    'speechModel',
  );
  @override
  late final GeneratedColumn<String> speechModel = GeneratedColumn<String>(
    'speech_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedTierMeta = const VerificationMeta(
    'speedTier',
  );
  @override
  late final GeneratedColumn<String> speedTier = GeneratedColumn<String>(
    'speed_tier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('medium'),
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
    'speed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _previewAudioUrlMeta = const VerificationMeta(
    'previewAudioUrl',
  );
  @override
  late final GeneratedColumn<String> previewAudioUrl = GeneratedColumn<String>(
    'preview_audio_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    id,
    name,
    kind,
    language,
    provider,
    providerVoiceId,
    speechModel,
    speedTier,
    speed,
    enabled,
    description,
    sortOrder,
    previewAudioUrl,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_voices';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedVoice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('provider_voice_id')) {
      context.handle(
        _providerVoiceIdMeta,
        providerVoiceId.isAcceptableOrUnknown(
          data['provider_voice_id']!,
          _providerVoiceIdMeta,
        ),
      );
    }
    if (data.containsKey('speech_model')) {
      context.handle(
        _speechModelMeta,
        speechModel.isAcceptableOrUnknown(
          data['speech_model']!,
          _speechModelMeta,
        ),
      );
    }
    if (data.containsKey('speed_tier')) {
      context.handle(
        _speedTierMeta,
        speedTier.isAcceptableOrUnknown(data['speed_tier']!, _speedTierMeta),
      );
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('preview_audio_url')) {
      context.handle(
        _previewAudioUrlMeta,
        previewAudioUrl.isAcceptableOrUnknown(
          data['preview_audio_url']!,
          _previewAudioUrlMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, id};
  @override
  CachedVoice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedVoice(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      providerVoiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_voice_id'],
      )!,
      speechModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speech_model'],
      ),
      speedTier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speed_tier'],
      )!,
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      previewAudioUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview_audio_url'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $CachedVoicesTable createAlias(String alias) {
    return $CachedVoicesTable(attachedDatabase, alias);
  }
}

class CachedVoice extends DataClass implements Insertable<CachedVoice> {
  final int userId;
  final int id;
  final String name;
  final String kind;
  final String language;
  final String provider;
  final String providerVoiceId;
  final String? speechModel;
  final String speedTier;
  final double speed;
  final bool enabled;
  final String? description;
  final int sortOrder;
  final String? previewAudioUrl;
  final DateTime syncedAt;
  const CachedVoice({
    required this.userId,
    required this.id,
    required this.name,
    required this.kind,
    required this.language,
    required this.provider,
    required this.providerVoiceId,
    this.speechModel,
    required this.speedTier,
    required this.speed,
    required this.enabled,
    this.description,
    required this.sortOrder,
    this.previewAudioUrl,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<int>(userId);
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    map['language'] = Variable<String>(language);
    map['provider'] = Variable<String>(provider);
    map['provider_voice_id'] = Variable<String>(providerVoiceId);
    if (!nullToAbsent || speechModel != null) {
      map['speech_model'] = Variable<String>(speechModel);
    }
    map['speed_tier'] = Variable<String>(speedTier);
    map['speed'] = Variable<double>(speed);
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || previewAudioUrl != null) {
      map['preview_audio_url'] = Variable<String>(previewAudioUrl);
    }
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  CachedVoicesCompanion toCompanion(bool nullToAbsent) {
    return CachedVoicesCompanion(
      userId: Value(userId),
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      language: Value(language),
      provider: Value(provider),
      providerVoiceId: Value(providerVoiceId),
      speechModel: speechModel == null && nullToAbsent
          ? const Value.absent()
          : Value(speechModel),
      speedTier: Value(speedTier),
      speed: Value(speed),
      enabled: Value(enabled),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      sortOrder: Value(sortOrder),
      previewAudioUrl: previewAudioUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(previewAudioUrl),
      syncedAt: Value(syncedAt),
    );
  }

  factory CachedVoice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedVoice(
      userId: serializer.fromJson<int>(json['userId']),
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      language: serializer.fromJson<String>(json['language']),
      provider: serializer.fromJson<String>(json['provider']),
      providerVoiceId: serializer.fromJson<String>(json['providerVoiceId']),
      speechModel: serializer.fromJson<String?>(json['speechModel']),
      speedTier: serializer.fromJson<String>(json['speedTier']),
      speed: serializer.fromJson<double>(json['speed']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      description: serializer.fromJson<String?>(json['description']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      previewAudioUrl: serializer.fromJson<String?>(json['previewAudioUrl']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<int>(userId),
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'language': serializer.toJson<String>(language),
      'provider': serializer.toJson<String>(provider),
      'providerVoiceId': serializer.toJson<String>(providerVoiceId),
      'speechModel': serializer.toJson<String?>(speechModel),
      'speedTier': serializer.toJson<String>(speedTier),
      'speed': serializer.toJson<double>(speed),
      'enabled': serializer.toJson<bool>(enabled),
      'description': serializer.toJson<String?>(description),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'previewAudioUrl': serializer.toJson<String?>(previewAudioUrl),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  CachedVoice copyWith({
    int? userId,
    int? id,
    String? name,
    String? kind,
    String? language,
    String? provider,
    String? providerVoiceId,
    Value<String?> speechModel = const Value.absent(),
    String? speedTier,
    double? speed,
    bool? enabled,
    Value<String?> description = const Value.absent(),
    int? sortOrder,
    Value<String?> previewAudioUrl = const Value.absent(),
    DateTime? syncedAt,
  }) => CachedVoice(
    userId: userId ?? this.userId,
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    language: language ?? this.language,
    provider: provider ?? this.provider,
    providerVoiceId: providerVoiceId ?? this.providerVoiceId,
    speechModel: speechModel.present ? speechModel.value : this.speechModel,
    speedTier: speedTier ?? this.speedTier,
    speed: speed ?? this.speed,
    enabled: enabled ?? this.enabled,
    description: description.present ? description.value : this.description,
    sortOrder: sortOrder ?? this.sortOrder,
    previewAudioUrl: previewAudioUrl.present
        ? previewAudioUrl.value
        : this.previewAudioUrl,
    syncedAt: syncedAt ?? this.syncedAt,
  );
  CachedVoice copyWithCompanion(CachedVoicesCompanion data) {
    return CachedVoice(
      userId: data.userId.present ? data.userId.value : this.userId,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      language: data.language.present ? data.language.value : this.language,
      provider: data.provider.present ? data.provider.value : this.provider,
      providerVoiceId: data.providerVoiceId.present
          ? data.providerVoiceId.value
          : this.providerVoiceId,
      speechModel: data.speechModel.present
          ? data.speechModel.value
          : this.speechModel,
      speedTier: data.speedTier.present ? data.speedTier.value : this.speedTier,
      speed: data.speed.present ? data.speed.value : this.speed,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      description: data.description.present
          ? data.description.value
          : this.description,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      previewAudioUrl: data.previewAudioUrl.present
          ? data.previewAudioUrl.value
          : this.previewAudioUrl,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedVoice(')
          ..write('userId: $userId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('language: $language, ')
          ..write('provider: $provider, ')
          ..write('providerVoiceId: $providerVoiceId, ')
          ..write('speechModel: $speechModel, ')
          ..write('speedTier: $speedTier, ')
          ..write('speed: $speed, ')
          ..write('enabled: $enabled, ')
          ..write('description: $description, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('previewAudioUrl: $previewAudioUrl, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    id,
    name,
    kind,
    language,
    provider,
    providerVoiceId,
    speechModel,
    speedTier,
    speed,
    enabled,
    description,
    sortOrder,
    previewAudioUrl,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedVoice &&
          other.userId == this.userId &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.language == this.language &&
          other.provider == this.provider &&
          other.providerVoiceId == this.providerVoiceId &&
          other.speechModel == this.speechModel &&
          other.speedTier == this.speedTier &&
          other.speed == this.speed &&
          other.enabled == this.enabled &&
          other.description == this.description &&
          other.sortOrder == this.sortOrder &&
          other.previewAudioUrl == this.previewAudioUrl &&
          other.syncedAt == this.syncedAt);
}

class CachedVoicesCompanion extends UpdateCompanion<CachedVoice> {
  final Value<int> userId;
  final Value<int> id;
  final Value<String> name;
  final Value<String> kind;
  final Value<String> language;
  final Value<String> provider;
  final Value<String> providerVoiceId;
  final Value<String?> speechModel;
  final Value<String> speedTier;
  final Value<double> speed;
  final Value<bool> enabled;
  final Value<String?> description;
  final Value<int> sortOrder;
  final Value<String?> previewAudioUrl;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const CachedVoicesCompanion({
    this.userId = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.language = const Value.absent(),
    this.provider = const Value.absent(),
    this.providerVoiceId = const Value.absent(),
    this.speechModel = const Value.absent(),
    this.speedTier = const Value.absent(),
    this.speed = const Value.absent(),
    this.enabled = const Value.absent(),
    this.description = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.previewAudioUrl = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedVoicesCompanion.insert({
    required int userId,
    required int id,
    required String name,
    this.kind = const Value.absent(),
    this.language = const Value.absent(),
    this.provider = const Value.absent(),
    this.providerVoiceId = const Value.absent(),
    this.speechModel = const Value.absent(),
    this.speedTier = const Value.absent(),
    this.speed = const Value.absent(),
    this.enabled = const Value.absent(),
    this.description = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.previewAudioUrl = const Value.absent(),
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       id = Value(id),
       name = Value(name),
       syncedAt = Value(syncedAt);
  static Insertable<CachedVoice> custom({
    Expression<int>? userId,
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? language,
    Expression<String>? provider,
    Expression<String>? providerVoiceId,
    Expression<String>? speechModel,
    Expression<String>? speedTier,
    Expression<double>? speed,
    Expression<bool>? enabled,
    Expression<String>? description,
    Expression<int>? sortOrder,
    Expression<String>? previewAudioUrl,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (language != null) 'language': language,
      if (provider != null) 'provider': provider,
      if (providerVoiceId != null) 'provider_voice_id': providerVoiceId,
      if (speechModel != null) 'speech_model': speechModel,
      if (speedTier != null) 'speed_tier': speedTier,
      if (speed != null) 'speed': speed,
      if (enabled != null) 'enabled': enabled,
      if (description != null) 'description': description,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (previewAudioUrl != null) 'preview_audio_url': previewAudioUrl,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedVoicesCompanion copyWith({
    Value<int>? userId,
    Value<int>? id,
    Value<String>? name,
    Value<String>? kind,
    Value<String>? language,
    Value<String>? provider,
    Value<String>? providerVoiceId,
    Value<String?>? speechModel,
    Value<String>? speedTier,
    Value<double>? speed,
    Value<bool>? enabled,
    Value<String?>? description,
    Value<int>? sortOrder,
    Value<String?>? previewAudioUrl,
    Value<DateTime>? syncedAt,
    Value<int>? rowid,
  }) {
    return CachedVoicesCompanion(
      userId: userId ?? this.userId,
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      language: language ?? this.language,
      provider: provider ?? this.provider,
      providerVoiceId: providerVoiceId ?? this.providerVoiceId,
      speechModel: speechModel ?? this.speechModel,
      speedTier: speedTier ?? this.speedTier,
      speed: speed ?? this.speed,
      enabled: enabled ?? this.enabled,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      previewAudioUrl: previewAudioUrl ?? this.previewAudioUrl,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (providerVoiceId.present) {
      map['provider_voice_id'] = Variable<String>(providerVoiceId.value);
    }
    if (speechModel.present) {
      map['speech_model'] = Variable<String>(speechModel.value);
    }
    if (speedTier.present) {
      map['speed_tier'] = Variable<String>(speedTier.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (previewAudioUrl.present) {
      map['preview_audio_url'] = Variable<String>(previewAudioUrl.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedVoicesCompanion(')
          ..write('userId: $userId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('language: $language, ')
          ..write('provider: $provider, ')
          ..write('providerVoiceId: $providerVoiceId, ')
          ..write('speechModel: $speechModel, ')
          ..write('speedTier: $speedTier, ')
          ..write('speed: $speed, ')
          ..write('enabled: $enabled, ')
          ..write('description: $description, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('previewAudioUrl: $previewAudioUrl, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedVoicePrefsTable extends CachedVoicePrefs
    with TableInfo<$CachedVoicePrefsTable, CachedVoicePref> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedVoicePrefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<int> childId = GeneratedColumn<int>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speedTierMeta = const VerificationMeta(
    'speedTier',
  );
  @override
  late final GeneratedColumn<String> speedTier = GeneratedColumn<String>(
    'speed_tier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('medium'),
  );
  static const VerificationMeta _tonePresetMeta = const VerificationMeta(
    'tonePreset',
  );
  @override
  late final GeneratedColumn<String> tonePreset = GeneratedColumn<String>(
    'tone_preset',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('gentle'),
  );
  static const VerificationMeta _likenessBoostMeta = const VerificationMeta(
    'likenessBoost',
  );
  @override
  late final GeneratedColumn<bool> likenessBoost = GeneratedColumn<bool>(
    'likeness_boost',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("likeness_boost" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _defaultVoiceIdMeta = const VerificationMeta(
    'defaultVoiceId',
  );
  @override
  late final GeneratedColumn<int> defaultVoiceId = GeneratedColumn<int>(
    'default_voice_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    childId,
    speedTier,
    tonePreset,
    likenessBoost,
    defaultVoiceId,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_voice_prefs';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedVoicePref> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('speed_tier')) {
      context.handle(
        _speedTierMeta,
        speedTier.isAcceptableOrUnknown(data['speed_tier']!, _speedTierMeta),
      );
    }
    if (data.containsKey('tone_preset')) {
      context.handle(
        _tonePresetMeta,
        tonePreset.isAcceptableOrUnknown(data['tone_preset']!, _tonePresetMeta),
      );
    }
    if (data.containsKey('likeness_boost')) {
      context.handle(
        _likenessBoostMeta,
        likenessBoost.isAcceptableOrUnknown(
          data['likeness_boost']!,
          _likenessBoostMeta,
        ),
      );
    }
    if (data.containsKey('default_voice_id')) {
      context.handle(
        _defaultVoiceIdMeta,
        defaultVoiceId.isAcceptableOrUnknown(
          data['default_voice_id']!,
          _defaultVoiceIdMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, childId};
  @override
  CachedVoicePref map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedVoicePref(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}child_id'],
      )!,
      speedTier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speed_tier'],
      )!,
      tonePreset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tone_preset'],
      )!,
      likenessBoost: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}likeness_boost'],
      )!,
      defaultVoiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_voice_id'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $CachedVoicePrefsTable createAlias(String alias) {
    return $CachedVoicePrefsTable(attachedDatabase, alias);
  }
}

class CachedVoicePref extends DataClass implements Insertable<CachedVoicePref> {
  final int userId;
  final int childId;
  final String speedTier;
  final String tonePreset;
  final bool likenessBoost;
  final int? defaultVoiceId;
  final DateTime syncedAt;
  const CachedVoicePref({
    required this.userId,
    required this.childId,
    required this.speedTier,
    required this.tonePreset,
    required this.likenessBoost,
    this.defaultVoiceId,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<int>(userId);
    map['child_id'] = Variable<int>(childId);
    map['speed_tier'] = Variable<String>(speedTier);
    map['tone_preset'] = Variable<String>(tonePreset);
    map['likeness_boost'] = Variable<bool>(likenessBoost);
    if (!nullToAbsent || defaultVoiceId != null) {
      map['default_voice_id'] = Variable<int>(defaultVoiceId);
    }
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  CachedVoicePrefsCompanion toCompanion(bool nullToAbsent) {
    return CachedVoicePrefsCompanion(
      userId: Value(userId),
      childId: Value(childId),
      speedTier: Value(speedTier),
      tonePreset: Value(tonePreset),
      likenessBoost: Value(likenessBoost),
      defaultVoiceId: defaultVoiceId == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultVoiceId),
      syncedAt: Value(syncedAt),
    );
  }

  factory CachedVoicePref.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedVoicePref(
      userId: serializer.fromJson<int>(json['userId']),
      childId: serializer.fromJson<int>(json['childId']),
      speedTier: serializer.fromJson<String>(json['speedTier']),
      tonePreset: serializer.fromJson<String>(json['tonePreset']),
      likenessBoost: serializer.fromJson<bool>(json['likenessBoost']),
      defaultVoiceId: serializer.fromJson<int?>(json['defaultVoiceId']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<int>(userId),
      'childId': serializer.toJson<int>(childId),
      'speedTier': serializer.toJson<String>(speedTier),
      'tonePreset': serializer.toJson<String>(tonePreset),
      'likenessBoost': serializer.toJson<bool>(likenessBoost),
      'defaultVoiceId': serializer.toJson<int?>(defaultVoiceId),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  CachedVoicePref copyWith({
    int? userId,
    int? childId,
    String? speedTier,
    String? tonePreset,
    bool? likenessBoost,
    Value<int?> defaultVoiceId = const Value.absent(),
    DateTime? syncedAt,
  }) => CachedVoicePref(
    userId: userId ?? this.userId,
    childId: childId ?? this.childId,
    speedTier: speedTier ?? this.speedTier,
    tonePreset: tonePreset ?? this.tonePreset,
    likenessBoost: likenessBoost ?? this.likenessBoost,
    defaultVoiceId: defaultVoiceId.present
        ? defaultVoiceId.value
        : this.defaultVoiceId,
    syncedAt: syncedAt ?? this.syncedAt,
  );
  CachedVoicePref copyWithCompanion(CachedVoicePrefsCompanion data) {
    return CachedVoicePref(
      userId: data.userId.present ? data.userId.value : this.userId,
      childId: data.childId.present ? data.childId.value : this.childId,
      speedTier: data.speedTier.present ? data.speedTier.value : this.speedTier,
      tonePreset: data.tonePreset.present
          ? data.tonePreset.value
          : this.tonePreset,
      likenessBoost: data.likenessBoost.present
          ? data.likenessBoost.value
          : this.likenessBoost,
      defaultVoiceId: data.defaultVoiceId.present
          ? data.defaultVoiceId.value
          : this.defaultVoiceId,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedVoicePref(')
          ..write('userId: $userId, ')
          ..write('childId: $childId, ')
          ..write('speedTier: $speedTier, ')
          ..write('tonePreset: $tonePreset, ')
          ..write('likenessBoost: $likenessBoost, ')
          ..write('defaultVoiceId: $defaultVoiceId, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    childId,
    speedTier,
    tonePreset,
    likenessBoost,
    defaultVoiceId,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedVoicePref &&
          other.userId == this.userId &&
          other.childId == this.childId &&
          other.speedTier == this.speedTier &&
          other.tonePreset == this.tonePreset &&
          other.likenessBoost == this.likenessBoost &&
          other.defaultVoiceId == this.defaultVoiceId &&
          other.syncedAt == this.syncedAt);
}

class CachedVoicePrefsCompanion extends UpdateCompanion<CachedVoicePref> {
  final Value<int> userId;
  final Value<int> childId;
  final Value<String> speedTier;
  final Value<String> tonePreset;
  final Value<bool> likenessBoost;
  final Value<int?> defaultVoiceId;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const CachedVoicePrefsCompanion({
    this.userId = const Value.absent(),
    this.childId = const Value.absent(),
    this.speedTier = const Value.absent(),
    this.tonePreset = const Value.absent(),
    this.likenessBoost = const Value.absent(),
    this.defaultVoiceId = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedVoicePrefsCompanion.insert({
    required int userId,
    required int childId,
    this.speedTier = const Value.absent(),
    this.tonePreset = const Value.absent(),
    this.likenessBoost = const Value.absent(),
    this.defaultVoiceId = const Value.absent(),
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       childId = Value(childId),
       syncedAt = Value(syncedAt);
  static Insertable<CachedVoicePref> custom({
    Expression<int>? userId,
    Expression<int>? childId,
    Expression<String>? speedTier,
    Expression<String>? tonePreset,
    Expression<bool>? likenessBoost,
    Expression<int>? defaultVoiceId,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (childId != null) 'child_id': childId,
      if (speedTier != null) 'speed_tier': speedTier,
      if (tonePreset != null) 'tone_preset': tonePreset,
      if (likenessBoost != null) 'likeness_boost': likenessBoost,
      if (defaultVoiceId != null) 'default_voice_id': defaultVoiceId,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedVoicePrefsCompanion copyWith({
    Value<int>? userId,
    Value<int>? childId,
    Value<String>? speedTier,
    Value<String>? tonePreset,
    Value<bool>? likenessBoost,
    Value<int?>? defaultVoiceId,
    Value<DateTime>? syncedAt,
    Value<int>? rowid,
  }) {
    return CachedVoicePrefsCompanion(
      userId: userId ?? this.userId,
      childId: childId ?? this.childId,
      speedTier: speedTier ?? this.speedTier,
      tonePreset: tonePreset ?? this.tonePreset,
      likenessBoost: likenessBoost ?? this.likenessBoost,
      defaultVoiceId: defaultVoiceId ?? this.defaultVoiceId,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<int>(childId.value);
    }
    if (speedTier.present) {
      map['speed_tier'] = Variable<String>(speedTier.value);
    }
    if (tonePreset.present) {
      map['tone_preset'] = Variable<String>(tonePreset.value);
    }
    if (likenessBoost.present) {
      map['likeness_boost'] = Variable<bool>(likenessBoost.value);
    }
    if (defaultVoiceId.present) {
      map['default_voice_id'] = Variable<int>(defaultVoiceId.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedVoicePrefsCompanion(')
          ..write('userId: $userId, ')
          ..write('childId: $childId, ')
          ..write('speedTier: $speedTier, ')
          ..write('tonePreset: $tonePreset, ')
          ..write('likenessBoost: $likenessBoost, ')
          ..write('defaultVoiceId: $defaultVoiceId, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountSnapshotsTable extends AccountSnapshots
    with TableInfo<$AccountSnapshotsTable, AccountSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preferredLanguageMeta = const VerificationMeta(
    'preferredLanguage',
  );
  @override
  late final GeneratedColumn<String> preferredLanguage =
      GeneratedColumn<String>(
        'preferred_language',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('zh'),
      );
  static const VerificationMeta _quotaMonthMeta = const VerificationMeta(
    'quotaMonth',
  );
  @override
  late final GeneratedColumn<String> quotaMonth = GeneratedColumn<String>(
    'quota_month',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _storyUsedMeta = const VerificationMeta(
    'storyUsed',
  );
  @override
  late final GeneratedColumn<int> storyUsed = GeneratedColumn<int>(
    'story_used',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _storyLimitMeta = const VerificationMeta(
    'storyLimit',
  );
  @override
  late final GeneratedColumn<int> storyLimit = GeneratedColumn<int>(
    'story_limit',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cloneUsedMeta = const VerificationMeta(
    'cloneUsed',
  );
  @override
  late final GeneratedColumn<int> cloneUsed = GeneratedColumn<int>(
    'clone_used',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cloneLimitMeta = const VerificationMeta(
    'cloneLimit',
  );
  @override
  late final GeneratedColumn<int> cloneLimit = GeneratedColumn<int>(
    'clone_limit',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    displayName,
    preferredLanguage,
    quotaMonth,
    storyUsed,
    storyLimit,
    cloneUsed,
    cloneLimit,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'account_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('preferred_language')) {
      context.handle(
        _preferredLanguageMeta,
        preferredLanguage.isAcceptableOrUnknown(
          data['preferred_language']!,
          _preferredLanguageMeta,
        ),
      );
    }
    if (data.containsKey('quota_month')) {
      context.handle(
        _quotaMonthMeta,
        quotaMonth.isAcceptableOrUnknown(data['quota_month']!, _quotaMonthMeta),
      );
    }
    if (data.containsKey('story_used')) {
      context.handle(
        _storyUsedMeta,
        storyUsed.isAcceptableOrUnknown(data['story_used']!, _storyUsedMeta),
      );
    }
    if (data.containsKey('story_limit')) {
      context.handle(
        _storyLimitMeta,
        storyLimit.isAcceptableOrUnknown(data['story_limit']!, _storyLimitMeta),
      );
    }
    if (data.containsKey('clone_used')) {
      context.handle(
        _cloneUsedMeta,
        cloneUsed.isAcceptableOrUnknown(data['clone_used']!, _cloneUsedMeta),
      );
    }
    if (data.containsKey('clone_limit')) {
      context.handle(
        _cloneLimitMeta,
        cloneLimit.isAcceptableOrUnknown(data['clone_limit']!, _cloneLimitMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  AccountSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountSnapshot(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      preferredLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_language'],
      )!,
      quotaMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quota_month'],
      ),
      storyUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}story_used'],
      )!,
      storyLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}story_limit'],
      )!,
      cloneUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}clone_used'],
      )!,
      cloneLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}clone_limit'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $AccountSnapshotsTable createAlias(String alias) {
    return $AccountSnapshotsTable(attachedDatabase, alias);
  }
}

class AccountSnapshot extends DataClass implements Insertable<AccountSnapshot> {
  final int userId;
  final String? displayName;
  final String preferredLanguage;
  final String? quotaMonth;
  final int storyUsed;
  final int storyLimit;
  final int cloneUsed;
  final int cloneLimit;
  final DateTime syncedAt;
  const AccountSnapshot({
    required this.userId,
    this.displayName,
    required this.preferredLanguage,
    this.quotaMonth,
    required this.storyUsed,
    required this.storyLimit,
    required this.cloneUsed,
    required this.cloneLimit,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<int>(userId);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['preferred_language'] = Variable<String>(preferredLanguage);
    if (!nullToAbsent || quotaMonth != null) {
      map['quota_month'] = Variable<String>(quotaMonth);
    }
    map['story_used'] = Variable<int>(storyUsed);
    map['story_limit'] = Variable<int>(storyLimit);
    map['clone_used'] = Variable<int>(cloneUsed);
    map['clone_limit'] = Variable<int>(cloneLimit);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  AccountSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return AccountSnapshotsCompanion(
      userId: Value(userId),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      preferredLanguage: Value(preferredLanguage),
      quotaMonth: quotaMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(quotaMonth),
      storyUsed: Value(storyUsed),
      storyLimit: Value(storyLimit),
      cloneUsed: Value(cloneUsed),
      cloneLimit: Value(cloneLimit),
      syncedAt: Value(syncedAt),
    );
  }

  factory AccountSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountSnapshot(
      userId: serializer.fromJson<int>(json['userId']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      preferredLanguage: serializer.fromJson<String>(json['preferredLanguage']),
      quotaMonth: serializer.fromJson<String?>(json['quotaMonth']),
      storyUsed: serializer.fromJson<int>(json['storyUsed']),
      storyLimit: serializer.fromJson<int>(json['storyLimit']),
      cloneUsed: serializer.fromJson<int>(json['cloneUsed']),
      cloneLimit: serializer.fromJson<int>(json['cloneLimit']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<int>(userId),
      'displayName': serializer.toJson<String?>(displayName),
      'preferredLanguage': serializer.toJson<String>(preferredLanguage),
      'quotaMonth': serializer.toJson<String?>(quotaMonth),
      'storyUsed': serializer.toJson<int>(storyUsed),
      'storyLimit': serializer.toJson<int>(storyLimit),
      'cloneUsed': serializer.toJson<int>(cloneUsed),
      'cloneLimit': serializer.toJson<int>(cloneLimit),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  AccountSnapshot copyWith({
    int? userId,
    Value<String?> displayName = const Value.absent(),
    String? preferredLanguage,
    Value<String?> quotaMonth = const Value.absent(),
    int? storyUsed,
    int? storyLimit,
    int? cloneUsed,
    int? cloneLimit,
    DateTime? syncedAt,
  }) => AccountSnapshot(
    userId: userId ?? this.userId,
    displayName: displayName.present ? displayName.value : this.displayName,
    preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    quotaMonth: quotaMonth.present ? quotaMonth.value : this.quotaMonth,
    storyUsed: storyUsed ?? this.storyUsed,
    storyLimit: storyLimit ?? this.storyLimit,
    cloneUsed: cloneUsed ?? this.cloneUsed,
    cloneLimit: cloneLimit ?? this.cloneLimit,
    syncedAt: syncedAt ?? this.syncedAt,
  );
  AccountSnapshot copyWithCompanion(AccountSnapshotsCompanion data) {
    return AccountSnapshot(
      userId: data.userId.present ? data.userId.value : this.userId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      preferredLanguage: data.preferredLanguage.present
          ? data.preferredLanguage.value
          : this.preferredLanguage,
      quotaMonth: data.quotaMonth.present
          ? data.quotaMonth.value
          : this.quotaMonth,
      storyUsed: data.storyUsed.present ? data.storyUsed.value : this.storyUsed,
      storyLimit: data.storyLimit.present
          ? data.storyLimit.value
          : this.storyLimit,
      cloneUsed: data.cloneUsed.present ? data.cloneUsed.value : this.cloneUsed,
      cloneLimit: data.cloneLimit.present
          ? data.cloneLimit.value
          : this.cloneLimit,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountSnapshot(')
          ..write('userId: $userId, ')
          ..write('displayName: $displayName, ')
          ..write('preferredLanguage: $preferredLanguage, ')
          ..write('quotaMonth: $quotaMonth, ')
          ..write('storyUsed: $storyUsed, ')
          ..write('storyLimit: $storyLimit, ')
          ..write('cloneUsed: $cloneUsed, ')
          ..write('cloneLimit: $cloneLimit, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    displayName,
    preferredLanguage,
    quotaMonth,
    storyUsed,
    storyLimit,
    cloneUsed,
    cloneLimit,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountSnapshot &&
          other.userId == this.userId &&
          other.displayName == this.displayName &&
          other.preferredLanguage == this.preferredLanguage &&
          other.quotaMonth == this.quotaMonth &&
          other.storyUsed == this.storyUsed &&
          other.storyLimit == this.storyLimit &&
          other.cloneUsed == this.cloneUsed &&
          other.cloneLimit == this.cloneLimit &&
          other.syncedAt == this.syncedAt);
}

class AccountSnapshotsCompanion extends UpdateCompanion<AccountSnapshot> {
  final Value<int> userId;
  final Value<String?> displayName;
  final Value<String> preferredLanguage;
  final Value<String?> quotaMonth;
  final Value<int> storyUsed;
  final Value<int> storyLimit;
  final Value<int> cloneUsed;
  final Value<int> cloneLimit;
  final Value<DateTime> syncedAt;
  const AccountSnapshotsCompanion({
    this.userId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.preferredLanguage = const Value.absent(),
    this.quotaMonth = const Value.absent(),
    this.storyUsed = const Value.absent(),
    this.storyLimit = const Value.absent(),
    this.cloneUsed = const Value.absent(),
    this.cloneLimit = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  AccountSnapshotsCompanion.insert({
    this.userId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.preferredLanguage = const Value.absent(),
    this.quotaMonth = const Value.absent(),
    this.storyUsed = const Value.absent(),
    this.storyLimit = const Value.absent(),
    this.cloneUsed = const Value.absent(),
    this.cloneLimit = const Value.absent(),
    required DateTime syncedAt,
  }) : syncedAt = Value(syncedAt);
  static Insertable<AccountSnapshot> custom({
    Expression<int>? userId,
    Expression<String>? displayName,
    Expression<String>? preferredLanguage,
    Expression<String>? quotaMonth,
    Expression<int>? storyUsed,
    Expression<int>? storyLimit,
    Expression<int>? cloneUsed,
    Expression<int>? cloneLimit,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (displayName != null) 'display_name': displayName,
      if (preferredLanguage != null) 'preferred_language': preferredLanguage,
      if (quotaMonth != null) 'quota_month': quotaMonth,
      if (storyUsed != null) 'story_used': storyUsed,
      if (storyLimit != null) 'story_limit': storyLimit,
      if (cloneUsed != null) 'clone_used': cloneUsed,
      if (cloneLimit != null) 'clone_limit': cloneLimit,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  AccountSnapshotsCompanion copyWith({
    Value<int>? userId,
    Value<String?>? displayName,
    Value<String>? preferredLanguage,
    Value<String?>? quotaMonth,
    Value<int>? storyUsed,
    Value<int>? storyLimit,
    Value<int>? cloneUsed,
    Value<int>? cloneLimit,
    Value<DateTime>? syncedAt,
  }) {
    return AccountSnapshotsCompanion(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      quotaMonth: quotaMonth ?? this.quotaMonth,
      storyUsed: storyUsed ?? this.storyUsed,
      storyLimit: storyLimit ?? this.storyLimit,
      cloneUsed: cloneUsed ?? this.cloneUsed,
      cloneLimit: cloneLimit ?? this.cloneLimit,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (preferredLanguage.present) {
      map['preferred_language'] = Variable<String>(preferredLanguage.value);
    }
    if (quotaMonth.present) {
      map['quota_month'] = Variable<String>(quotaMonth.value);
    }
    if (storyUsed.present) {
      map['story_used'] = Variable<int>(storyUsed.value);
    }
    if (storyLimit.present) {
      map['story_limit'] = Variable<int>(storyLimit.value);
    }
    if (cloneUsed.present) {
      map['clone_used'] = Variable<int>(cloneUsed.value);
    }
    if (cloneLimit.present) {
      map['clone_limit'] = Variable<int>(cloneLimit.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountSnapshotsCompanion(')
          ..write('userId: $userId, ')
          ..write('displayName: $displayName, ')
          ..write('preferredLanguage: $preferredLanguage, ')
          ..write('quotaMonth: $quotaMonth, ')
          ..write('storyUsed: $storyUsed, ')
          ..write('storyLimit: $storyLimit, ')
          ..write('cloneUsed: $cloneUsed, ')
          ..write('cloneLimit: $cloneLimit, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $MediaFilesTable extends MediaFiles
    with TableInfo<$MediaFilesTable, MediaFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storyIdMeta = const VerificationMeta(
    'storyId',
  );
  @override
  late final GeneratedColumn<int> storyId = GeneratedColumn<int>(
    'story_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPlayedAt = GeneratedColumn<DateTime>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readyMeta = const VerificationMeta('ready');
  @override
  late final GeneratedColumn<bool> ready = GeneratedColumn<bool>(
    'ready',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ready" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    storyId,
    localPath,
    sizeBytes,
    lastPlayedAt,
    ready,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaFile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('story_id')) {
      context.handle(
        _storyIdMeta,
        storyId.isAcceptableOrUnknown(data['story_id']!, _storyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storyIdMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    if (data.containsKey('ready')) {
      context.handle(
        _readyMeta,
        ready.isAcceptableOrUnknown(data['ready']!, _readyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, storyId};
  @override
  MediaFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaFile(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      storyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}story_id'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_played_at'],
      ),
      ready: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ready'],
      )!,
    );
  }

  @override
  $MediaFilesTable createAlias(String alias) {
    return $MediaFilesTable(attachedDatabase, alias);
  }
}

class MediaFile extends DataClass implements Insertable<MediaFile> {
  final int userId;
  final int storyId;
  final String localPath;
  final int sizeBytes;
  final DateTime? lastPlayedAt;
  final bool ready;
  const MediaFile({
    required this.userId,
    required this.storyId,
    required this.localPath,
    required this.sizeBytes,
    this.lastPlayedAt,
    required this.ready,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<int>(userId);
    map['story_id'] = Variable<int>(storyId);
    map['local_path'] = Variable<String>(localPath);
    map['size_bytes'] = Variable<int>(sizeBytes);
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt);
    }
    map['ready'] = Variable<bool>(ready);
    return map;
  }

  MediaFilesCompanion toCompanion(bool nullToAbsent) {
    return MediaFilesCompanion(
      userId: Value(userId),
      storyId: Value(storyId),
      localPath: Value(localPath),
      sizeBytes: Value(sizeBytes),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
      ready: Value(ready),
    );
  }

  factory MediaFile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaFile(
      userId: serializer.fromJson<int>(json['userId']),
      storyId: serializer.fromJson<int>(json['storyId']),
      localPath: serializer.fromJson<String>(json['localPath']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      lastPlayedAt: serializer.fromJson<DateTime?>(json['lastPlayedAt']),
      ready: serializer.fromJson<bool>(json['ready']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<int>(userId),
      'storyId': serializer.toJson<int>(storyId),
      'localPath': serializer.toJson<String>(localPath),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'lastPlayedAt': serializer.toJson<DateTime?>(lastPlayedAt),
      'ready': serializer.toJson<bool>(ready),
    };
  }

  MediaFile copyWith({
    int? userId,
    int? storyId,
    String? localPath,
    int? sizeBytes,
    Value<DateTime?> lastPlayedAt = const Value.absent(),
    bool? ready,
  }) => MediaFile(
    userId: userId ?? this.userId,
    storyId: storyId ?? this.storyId,
    localPath: localPath ?? this.localPath,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
    ready: ready ?? this.ready,
  );
  MediaFile copyWithCompanion(MediaFilesCompanion data) {
    return MediaFile(
      userId: data.userId.present ? data.userId.value : this.userId,
      storyId: data.storyId.present ? data.storyId.value : this.storyId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
      ready: data.ready.present ? data.ready.value : this.ready,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaFile(')
          ..write('userId: $userId, ')
          ..write('storyId: $storyId, ')
          ..write('localPath: $localPath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('ready: $ready')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(userId, storyId, localPath, sizeBytes, lastPlayedAt, ready);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaFile &&
          other.userId == this.userId &&
          other.storyId == this.storyId &&
          other.localPath == this.localPath &&
          other.sizeBytes == this.sizeBytes &&
          other.lastPlayedAt == this.lastPlayedAt &&
          other.ready == this.ready);
}

class MediaFilesCompanion extends UpdateCompanion<MediaFile> {
  final Value<int> userId;
  final Value<int> storyId;
  final Value<String> localPath;
  final Value<int> sizeBytes;
  final Value<DateTime?> lastPlayedAt;
  final Value<bool> ready;
  final Value<int> rowid;
  const MediaFilesCompanion({
    this.userId = const Value.absent(),
    this.storyId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.ready = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaFilesCompanion.insert({
    required int userId,
    required int storyId,
    required String localPath,
    this.sizeBytes = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.ready = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       storyId = Value(storyId),
       localPath = Value(localPath);
  static Insertable<MediaFile> custom({
    Expression<int>? userId,
    Expression<int>? storyId,
    Expression<String>? localPath,
    Expression<int>? sizeBytes,
    Expression<DateTime>? lastPlayedAt,
    Expression<bool>? ready,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (storyId != null) 'story_id': storyId,
      if (localPath != null) 'local_path': localPath,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (ready != null) 'ready': ready,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaFilesCompanion copyWith({
    Value<int>? userId,
    Value<int>? storyId,
    Value<String>? localPath,
    Value<int>? sizeBytes,
    Value<DateTime?>? lastPlayedAt,
    Value<bool>? ready,
    Value<int>? rowid,
  }) {
    return MediaFilesCompanion(
      userId: userId ?? this.userId,
      storyId: storyId ?? this.storyId,
      localPath: localPath ?? this.localPath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      ready: ready ?? this.ready,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (storyId.present) {
      map['story_id'] = Variable<int>(storyId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt.value);
    }
    if (ready.present) {
      map['ready'] = Variable<bool>(ready.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaFilesCompanion(')
          ..write('userId: $userId, ')
          ..write('storyId: $storyId, ')
          ..write('localPath: $localPath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('ready: $ready, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaybackProgressTable extends PlaybackProgress
    with TableInfo<$PlaybackProgressTable, PlaybackProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storyIdMeta = const VerificationMeta(
    'storyId',
  );
  @override
  late final GeneratedColumn<int> storyId = GeneratedColumn<int>(
    'story_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    storyId,
    positionMs,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackProgressData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('story_id')) {
      context.handle(
        _storyIdMeta,
        storyId.isAcceptableOrUnknown(data['story_id']!, _storyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storyIdMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, storyId};
  @override
  PlaybackProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackProgressData(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      storyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}story_id'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaybackProgressTable createAlias(String alias) {
    return $PlaybackProgressTable(attachedDatabase, alias);
  }
}

class PlaybackProgressData extends DataClass
    implements Insertable<PlaybackProgressData> {
  final int userId;
  final int storyId;
  final int positionMs;
  final DateTime updatedAt;
  const PlaybackProgressData({
    required this.userId,
    required this.storyId,
    required this.positionMs,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<int>(userId);
    map['story_id'] = Variable<int>(storyId);
    map['position_ms'] = Variable<int>(positionMs);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaybackProgressCompanion toCompanion(bool nullToAbsent) {
    return PlaybackProgressCompanion(
      userId: Value(userId),
      storyId: Value(storyId),
      positionMs: Value(positionMs),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaybackProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackProgressData(
      userId: serializer.fromJson<int>(json['userId']),
      storyId: serializer.fromJson<int>(json['storyId']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<int>(userId),
      'storyId': serializer.toJson<int>(storyId),
      'positionMs': serializer.toJson<int>(positionMs),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlaybackProgressData copyWith({
    int? userId,
    int? storyId,
    int? positionMs,
    DateTime? updatedAt,
  }) => PlaybackProgressData(
    userId: userId ?? this.userId,
    storyId: storyId ?? this.storyId,
    positionMs: positionMs ?? this.positionMs,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaybackProgressData copyWithCompanion(PlaybackProgressCompanion data) {
    return PlaybackProgressData(
      userId: data.userId.present ? data.userId.value : this.userId,
      storyId: data.storyId.present ? data.storyId.value : this.storyId,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackProgressData(')
          ..write('userId: $userId, ')
          ..write('storyId: $storyId, ')
          ..write('positionMs: $positionMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, storyId, positionMs, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackProgressData &&
          other.userId == this.userId &&
          other.storyId == this.storyId &&
          other.positionMs == this.positionMs &&
          other.updatedAt == this.updatedAt);
}

class PlaybackProgressCompanion extends UpdateCompanion<PlaybackProgressData> {
  final Value<int> userId;
  final Value<int> storyId;
  final Value<int> positionMs;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlaybackProgressCompanion({
    this.userId = const Value.absent(),
    this.storyId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackProgressCompanion.insert({
    required int userId,
    required int storyId,
    this.positionMs = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       storyId = Value(storyId),
       updatedAt = Value(updatedAt);
  static Insertable<PlaybackProgressData> custom({
    Expression<int>? userId,
    Expression<int>? storyId,
    Expression<int>? positionMs,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (storyId != null) 'story_id': storyId,
      if (positionMs != null) 'position_ms': positionMs,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackProgressCompanion copyWith({
    Value<int>? userId,
    Value<int>? storyId,
    Value<int>? positionMs,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PlaybackProgressCompanion(
      userId: userId ?? this.userId,
      storyId: storyId ?? this.storyId,
      positionMs: positionMs ?? this.positionMs,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (storyId.present) {
      map['story_id'] = Variable<int>(storyId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackProgressCompanion(')
          ..write('userId: $userId, ')
          ..write('storyId: $storyId, ')
          ..write('positionMs: $positionMs, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoryFavoritesTable extends StoryFavorites
    with TableInfo<$StoryFavoritesTable, StoryFavorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoryFavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storyIdMeta = const VerificationMeta(
    'storyId',
  );
  @override
  late final GeneratedColumn<int> storyId = GeneratedColumn<int>(
    'story_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _favoritedAtMeta = const VerificationMeta(
    'favoritedAt',
  );
  @override
  late final GeneratedColumn<DateTime> favoritedAt = GeneratedColumn<DateTime>(
    'favorited_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [userId, storyId, favoritedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'story_favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoryFavorite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('story_id')) {
      context.handle(
        _storyIdMeta,
        storyId.isAcceptableOrUnknown(data['story_id']!, _storyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storyIdMeta);
    }
    if (data.containsKey('favorited_at')) {
      context.handle(
        _favoritedAtMeta,
        favoritedAt.isAcceptableOrUnknown(
          data['favorited_at']!,
          _favoritedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_favoritedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, storyId};
  @override
  StoryFavorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoryFavorite(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      storyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}story_id'],
      )!,
      favoritedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}favorited_at'],
      )!,
    );
  }

  @override
  $StoryFavoritesTable createAlias(String alias) {
    return $StoryFavoritesTable(attachedDatabase, alias);
  }
}

class StoryFavorite extends DataClass implements Insertable<StoryFavorite> {
  final int userId;
  final int storyId;
  final DateTime favoritedAt;
  const StoryFavorite({
    required this.userId,
    required this.storyId,
    required this.favoritedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<int>(userId);
    map['story_id'] = Variable<int>(storyId);
    map['favorited_at'] = Variable<DateTime>(favoritedAt);
    return map;
  }

  StoryFavoritesCompanion toCompanion(bool nullToAbsent) {
    return StoryFavoritesCompanion(
      userId: Value(userId),
      storyId: Value(storyId),
      favoritedAt: Value(favoritedAt),
    );
  }

  factory StoryFavorite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoryFavorite(
      userId: serializer.fromJson<int>(json['userId']),
      storyId: serializer.fromJson<int>(json['storyId']),
      favoritedAt: serializer.fromJson<DateTime>(json['favoritedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<int>(userId),
      'storyId': serializer.toJson<int>(storyId),
      'favoritedAt': serializer.toJson<DateTime>(favoritedAt),
    };
  }

  StoryFavorite copyWith({int? userId, int? storyId, DateTime? favoritedAt}) =>
      StoryFavorite(
        userId: userId ?? this.userId,
        storyId: storyId ?? this.storyId,
        favoritedAt: favoritedAt ?? this.favoritedAt,
      );
  StoryFavorite copyWithCompanion(StoryFavoritesCompanion data) {
    return StoryFavorite(
      userId: data.userId.present ? data.userId.value : this.userId,
      storyId: data.storyId.present ? data.storyId.value : this.storyId,
      favoritedAt: data.favoritedAt.present
          ? data.favoritedAt.value
          : this.favoritedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoryFavorite(')
          ..write('userId: $userId, ')
          ..write('storyId: $storyId, ')
          ..write('favoritedAt: $favoritedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, storyId, favoritedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoryFavorite &&
          other.userId == this.userId &&
          other.storyId == this.storyId &&
          other.favoritedAt == this.favoritedAt);
}

class StoryFavoritesCompanion extends UpdateCompanion<StoryFavorite> {
  final Value<int> userId;
  final Value<int> storyId;
  final Value<DateTime> favoritedAt;
  final Value<int> rowid;
  const StoryFavoritesCompanion({
    this.userId = const Value.absent(),
    this.storyId = const Value.absent(),
    this.favoritedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoryFavoritesCompanion.insert({
    required int userId,
    required int storyId,
    required DateTime favoritedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       storyId = Value(storyId),
       favoritedAt = Value(favoritedAt);
  static Insertable<StoryFavorite> custom({
    Expression<int>? userId,
    Expression<int>? storyId,
    Expression<DateTime>? favoritedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (storyId != null) 'story_id': storyId,
      if (favoritedAt != null) 'favorited_at': favoritedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoryFavoritesCompanion copyWith({
    Value<int>? userId,
    Value<int>? storyId,
    Value<DateTime>? favoritedAt,
    Value<int>? rowid,
  }) {
    return StoryFavoritesCompanion(
      userId: userId ?? this.userId,
      storyId: storyId ?? this.storyId,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (storyId.present) {
      map['story_id'] = Variable<int>(storyId.value);
    }
    if (favoritedAt.present) {
      map['favorited_at'] = Variable<DateTime>(favoritedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoryFavoritesCompanion(')
          ..write('userId: $userId, ')
          ..write('storyId: $storyId, ')
          ..write('favoritedAt: $favoritedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MoodEntriesTable extends MoodEntries
    with TableInfo<$MoodEntriesTable, MoodEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MoodEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<String> dayKey = GeneratedColumn<String>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<int> childId = GeneratedColumn<int>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  @override
  late final GeneratedColumn<String> mood = GeneratedColumn<String>(
    'mood',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _storyIdMeta = const VerificationMeta(
    'storyId',
  );
  @override
  late final GeneratedColumn<int> storyId = GeneratedColumn<int>(
    'story_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    dayKey,
    childId,
    mood,
    note,
    storyId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mood_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MoodEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('story_id')) {
      context.handle(
        _storyIdMeta,
        storyId.isAcceptableOrUnknown(data['story_id']!, _storyIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, dayKey, childId};
  @override
  MoodEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MoodEntry(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_key'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}child_id'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mood'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      storyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}story_id'],
      ),
    );
  }

  @override
  $MoodEntriesTable createAlias(String alias) {
    return $MoodEntriesTable(attachedDatabase, alias);
  }
}

class MoodEntry extends DataClass implements Insertable<MoodEntry> {
  final int userId;

  /// YYYY-MM-DD
  final String dayKey;
  final int childId;
  final String mood;
  final String? note;
  final int? storyId;
  const MoodEntry({
    required this.userId,
    required this.dayKey,
    required this.childId,
    required this.mood,
    this.note,
    this.storyId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<int>(userId);
    map['day_key'] = Variable<String>(dayKey);
    map['child_id'] = Variable<int>(childId);
    map['mood'] = Variable<String>(mood);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || storyId != null) {
      map['story_id'] = Variable<int>(storyId);
    }
    return map;
  }

  MoodEntriesCompanion toCompanion(bool nullToAbsent) {
    return MoodEntriesCompanion(
      userId: Value(userId),
      dayKey: Value(dayKey),
      childId: Value(childId),
      mood: Value(mood),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      storyId: storyId == null && nullToAbsent
          ? const Value.absent()
          : Value(storyId),
    );
  }

  factory MoodEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MoodEntry(
      userId: serializer.fromJson<int>(json['userId']),
      dayKey: serializer.fromJson<String>(json['dayKey']),
      childId: serializer.fromJson<int>(json['childId']),
      mood: serializer.fromJson<String>(json['mood']),
      note: serializer.fromJson<String?>(json['note']),
      storyId: serializer.fromJson<int?>(json['storyId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<int>(userId),
      'dayKey': serializer.toJson<String>(dayKey),
      'childId': serializer.toJson<int>(childId),
      'mood': serializer.toJson<String>(mood),
      'note': serializer.toJson<String?>(note),
      'storyId': serializer.toJson<int?>(storyId),
    };
  }

  MoodEntry copyWith({
    int? userId,
    String? dayKey,
    int? childId,
    String? mood,
    Value<String?> note = const Value.absent(),
    Value<int?> storyId = const Value.absent(),
  }) => MoodEntry(
    userId: userId ?? this.userId,
    dayKey: dayKey ?? this.dayKey,
    childId: childId ?? this.childId,
    mood: mood ?? this.mood,
    note: note.present ? note.value : this.note,
    storyId: storyId.present ? storyId.value : this.storyId,
  );
  MoodEntry copyWithCompanion(MoodEntriesCompanion data) {
    return MoodEntry(
      userId: data.userId.present ? data.userId.value : this.userId,
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      childId: data.childId.present ? data.childId.value : this.childId,
      mood: data.mood.present ? data.mood.value : this.mood,
      note: data.note.present ? data.note.value : this.note,
      storyId: data.storyId.present ? data.storyId.value : this.storyId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MoodEntry(')
          ..write('userId: $userId, ')
          ..write('dayKey: $dayKey, ')
          ..write('childId: $childId, ')
          ..write('mood: $mood, ')
          ..write('note: $note, ')
          ..write('storyId: $storyId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, dayKey, childId, mood, note, storyId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MoodEntry &&
          other.userId == this.userId &&
          other.dayKey == this.dayKey &&
          other.childId == this.childId &&
          other.mood == this.mood &&
          other.note == this.note &&
          other.storyId == this.storyId);
}

class MoodEntriesCompanion extends UpdateCompanion<MoodEntry> {
  final Value<int> userId;
  final Value<String> dayKey;
  final Value<int> childId;
  final Value<String> mood;
  final Value<String?> note;
  final Value<int?> storyId;
  final Value<int> rowid;
  const MoodEntriesCompanion({
    this.userId = const Value.absent(),
    this.dayKey = const Value.absent(),
    this.childId = const Value.absent(),
    this.mood = const Value.absent(),
    this.note = const Value.absent(),
    this.storyId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MoodEntriesCompanion.insert({
    required int userId,
    required String dayKey,
    required int childId,
    this.mood = const Value.absent(),
    this.note = const Value.absent(),
    this.storyId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       dayKey = Value(dayKey),
       childId = Value(childId);
  static Insertable<MoodEntry> custom({
    Expression<int>? userId,
    Expression<String>? dayKey,
    Expression<int>? childId,
    Expression<String>? mood,
    Expression<String>? note,
    Expression<int>? storyId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (dayKey != null) 'day_key': dayKey,
      if (childId != null) 'child_id': childId,
      if (mood != null) 'mood': mood,
      if (note != null) 'note': note,
      if (storyId != null) 'story_id': storyId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MoodEntriesCompanion copyWith({
    Value<int>? userId,
    Value<String>? dayKey,
    Value<int>? childId,
    Value<String>? mood,
    Value<String?>? note,
    Value<int?>? storyId,
    Value<int>? rowid,
  }) {
    return MoodEntriesCompanion(
      userId: userId ?? this.userId,
      dayKey: dayKey ?? this.dayKey,
      childId: childId ?? this.childId,
      mood: mood ?? this.mood,
      note: note ?? this.note,
      storyId: storyId ?? this.storyId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (dayKey.present) {
      map['day_key'] = Variable<String>(dayKey.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<int>(childId.value);
    }
    if (mood.present) {
      map['mood'] = Variable<String>(mood.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (storyId.present) {
      map['story_id'] = Variable<int>(storyId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MoodEntriesCompanion(')
          ..write('userId: $userId, ')
          ..write('dayKey: $dayKey, ')
          ..write('childId: $childId, ')
          ..write('mood: $mood, ')
          ..write('note: $note, ')
          ..write('storyId: $storyId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedStoriesTable cachedStories = $CachedStoriesTable(this);
  late final $CachedChildrenTable cachedChildren = $CachedChildrenTable(this);
  late final $CachedCharactersTable cachedCharacters = $CachedCharactersTable(
    this,
  );
  late final $CachedVoicesTable cachedVoices = $CachedVoicesTable(this);
  late final $CachedVoicePrefsTable cachedVoicePrefs = $CachedVoicePrefsTable(
    this,
  );
  late final $AccountSnapshotsTable accountSnapshots = $AccountSnapshotsTable(
    this,
  );
  late final $MediaFilesTable mediaFiles = $MediaFilesTable(this);
  late final $PlaybackProgressTable playbackProgress = $PlaybackProgressTable(
    this,
  );
  late final $StoryFavoritesTable storyFavorites = $StoryFavoritesTable(this);
  late final $MoodEntriesTable moodEntries = $MoodEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedStories,
    cachedChildren,
    cachedCharacters,
    cachedVoices,
    cachedVoicePrefs,
    accountSnapshots,
    mediaFiles,
    playbackProgress,
    storyFavorites,
    moodEntries,
  ];
}

typedef $$CachedStoriesTableCreateCompanionBuilder =
    CachedStoriesCompanion Function({
      required int userId,
      required int id,
      Value<String> title,
      Value<String> language,
      Value<String?> theme,
      Value<String> body,
      Value<String> status,
      Value<String> source,
      Value<String?> softHook,
      Value<String?> audioUrl,
      Value<int> durationMinutes,
      Value<int?> seriesId,
      Value<int?> episodeNo,
      Value<int?> childId,
      Value<String?> progress,
      Value<String?> errorMessage,
      Value<String?> voiceName,
      Value<String?> core,
      Value<String?> storyProvider,
      Value<String?> speechProvider,
      Value<String?> speechModel,
      required DateTime syncedAt,
      Value<int> rowid,
    });
typedef $$CachedStoriesTableUpdateCompanionBuilder =
    CachedStoriesCompanion Function({
      Value<int> userId,
      Value<int> id,
      Value<String> title,
      Value<String> language,
      Value<String?> theme,
      Value<String> body,
      Value<String> status,
      Value<String> source,
      Value<String?> softHook,
      Value<String?> audioUrl,
      Value<int> durationMinutes,
      Value<int?> seriesId,
      Value<int?> episodeNo,
      Value<int?> childId,
      Value<String?> progress,
      Value<String?> errorMessage,
      Value<String?> voiceName,
      Value<String?> core,
      Value<String?> storyProvider,
      Value<String?> speechProvider,
      Value<String?> speechModel,
      Value<DateTime> syncedAt,
      Value<int> rowid,
    });

class $$CachedStoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedStoriesTable> {
  $$CachedStoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get softHook => $composableBuilder(
    column: $table.softHook,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeNo => $composableBuilder(
    column: $table.episodeNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get childId => $composableBuilder(
    column: $table.childId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voiceName => $composableBuilder(
    column: $table.voiceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get core => $composableBuilder(
    column: $table.core,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storyProvider => $composableBuilder(
    column: $table.storyProvider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speechProvider => $composableBuilder(
    column: $table.speechProvider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speechModel => $composableBuilder(
    column: $table.speechModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedStoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedStoriesTable> {
  $$CachedStoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get softHook => $composableBuilder(
    column: $table.softHook,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeNo => $composableBuilder(
    column: $table.episodeNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get childId => $composableBuilder(
    column: $table.childId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voiceName => $composableBuilder(
    column: $table.voiceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get core => $composableBuilder(
    column: $table.core,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storyProvider => $composableBuilder(
    column: $table.storyProvider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speechProvider => $composableBuilder(
    column: $table.speechProvider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speechModel => $composableBuilder(
    column: $table.speechModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedStoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedStoriesTable> {
  $$CachedStoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get theme =>
      $composableBuilder(column: $table.theme, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get softHook =>
      $composableBuilder(column: $table.softHook, builder: (column) => column);

  GeneratedColumn<String> get audioUrl =>
      $composableBuilder(column: $table.audioUrl, builder: (column) => column);

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);

  GeneratedColumn<int> get episodeNo =>
      $composableBuilder(column: $table.episodeNo, builder: (column) => column);

  GeneratedColumn<int> get childId =>
      $composableBuilder(column: $table.childId, builder: (column) => column);

  GeneratedColumn<String> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voiceName =>
      $composableBuilder(column: $table.voiceName, builder: (column) => column);

  GeneratedColumn<String> get core =>
      $composableBuilder(column: $table.core, builder: (column) => column);

  GeneratedColumn<String> get storyProvider => $composableBuilder(
    column: $table.storyProvider,
    builder: (column) => column,
  );

  GeneratedColumn<String> get speechProvider => $composableBuilder(
    column: $table.speechProvider,
    builder: (column) => column,
  );

  GeneratedColumn<String> get speechModel => $composableBuilder(
    column: $table.speechModel,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$CachedStoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedStoriesTable,
          CachedStory,
          $$CachedStoriesTableFilterComposer,
          $$CachedStoriesTableOrderingComposer,
          $$CachedStoriesTableAnnotationComposer,
          $$CachedStoriesTableCreateCompanionBuilder,
          $$CachedStoriesTableUpdateCompanionBuilder,
          (
            CachedStory,
            BaseReferences<_$AppDatabase, $CachedStoriesTable, CachedStory>,
          ),
          CachedStory,
          PrefetchHooks Function()
        > {
  $$CachedStoriesTableTableManager(_$AppDatabase db, $CachedStoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedStoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedStoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedStoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> userId = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String?> theme = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> softHook = const Value.absent(),
                Value<String?> audioUrl = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<int?> seriesId = const Value.absent(),
                Value<int?> episodeNo = const Value.absent(),
                Value<int?> childId = const Value.absent(),
                Value<String?> progress = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> voiceName = const Value.absent(),
                Value<String?> core = const Value.absent(),
                Value<String?> storyProvider = const Value.absent(),
                Value<String?> speechProvider = const Value.absent(),
                Value<String?> speechModel = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedStoriesCompanion(
                userId: userId,
                id: id,
                title: title,
                language: language,
                theme: theme,
                body: body,
                status: status,
                source: source,
                softHook: softHook,
                audioUrl: audioUrl,
                durationMinutes: durationMinutes,
                seriesId: seriesId,
                episodeNo: episodeNo,
                childId: childId,
                progress: progress,
                errorMessage: errorMessage,
                voiceName: voiceName,
                core: core,
                storyProvider: storyProvider,
                speechProvider: speechProvider,
                speechModel: speechModel,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int userId,
                required int id,
                Value<String> title = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String?> theme = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> softHook = const Value.absent(),
                Value<String?> audioUrl = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<int?> seriesId = const Value.absent(),
                Value<int?> episodeNo = const Value.absent(),
                Value<int?> childId = const Value.absent(),
                Value<String?> progress = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> voiceName = const Value.absent(),
                Value<String?> core = const Value.absent(),
                Value<String?> storyProvider = const Value.absent(),
                Value<String?> speechProvider = const Value.absent(),
                Value<String?> speechModel = const Value.absent(),
                required DateTime syncedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedStoriesCompanion.insert(
                userId: userId,
                id: id,
                title: title,
                language: language,
                theme: theme,
                body: body,
                status: status,
                source: source,
                softHook: softHook,
                audioUrl: audioUrl,
                durationMinutes: durationMinutes,
                seriesId: seriesId,
                episodeNo: episodeNo,
                childId: childId,
                progress: progress,
                errorMessage: errorMessage,
                voiceName: voiceName,
                core: core,
                storyProvider: storyProvider,
                speechProvider: speechProvider,
                speechModel: speechModel,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedStoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedStoriesTable,
      CachedStory,
      $$CachedStoriesTableFilterComposer,
      $$CachedStoriesTableOrderingComposer,
      $$CachedStoriesTableAnnotationComposer,
      $$CachedStoriesTableCreateCompanionBuilder,
      $$CachedStoriesTableUpdateCompanionBuilder,
      (
        CachedStory,
        BaseReferences<_$AppDatabase, $CachedStoriesTable, CachedStory>,
      ),
      CachedStory,
      PrefetchHooks Function()
    >;
typedef $$CachedChildrenTableCreateCompanionBuilder =
    CachedChildrenCompanion Function({
      required int userId,
      required int id,
      required String nickname,
      Value<String?> birthDate,
      Value<String> ageBand,
      Value<String> gender,
      Value<String?> intro,
      Value<String> interestsJson,
      required DateTime syncedAt,
      Value<int> rowid,
    });
typedef $$CachedChildrenTableUpdateCompanionBuilder =
    CachedChildrenCompanion Function({
      Value<int> userId,
      Value<int> id,
      Value<String> nickname,
      Value<String?> birthDate,
      Value<String> ageBand,
      Value<String> gender,
      Value<String?> intro,
      Value<String> interestsJson,
      Value<DateTime> syncedAt,
      Value<int> rowid,
    });

class $$CachedChildrenTableFilterComposer
    extends Composer<_$AppDatabase, $CachedChildrenTable> {
  $$CachedChildrenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ageBand => $composableBuilder(
    column: $table.ageBand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get interestsJson => $composableBuilder(
    column: $table.interestsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedChildrenTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedChildrenTable> {
  $$CachedChildrenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ageBand => $composableBuilder(
    column: $table.ageBand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interestsJson => $composableBuilder(
    column: $table.interestsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedChildrenTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedChildrenTable> {
  $$CachedChildrenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<String> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<String> get ageBand =>
      $composableBuilder(column: $table.ageBand, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<String> get intro =>
      $composableBuilder(column: $table.intro, builder: (column) => column);

  GeneratedColumn<String> get interestsJson => $composableBuilder(
    column: $table.interestsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$CachedChildrenTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedChildrenTable,
          CachedChildrenData,
          $$CachedChildrenTableFilterComposer,
          $$CachedChildrenTableOrderingComposer,
          $$CachedChildrenTableAnnotationComposer,
          $$CachedChildrenTableCreateCompanionBuilder,
          $$CachedChildrenTableUpdateCompanionBuilder,
          (
            CachedChildrenData,
            BaseReferences<
              _$AppDatabase,
              $CachedChildrenTable,
              CachedChildrenData
            >,
          ),
          CachedChildrenData,
          PrefetchHooks Function()
        > {
  $$CachedChildrenTableTableManager(
    _$AppDatabase db,
    $CachedChildrenTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedChildrenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedChildrenTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedChildrenTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> userId = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> nickname = const Value.absent(),
                Value<String?> birthDate = const Value.absent(),
                Value<String> ageBand = const Value.absent(),
                Value<String> gender = const Value.absent(),
                Value<String?> intro = const Value.absent(),
                Value<String> interestsJson = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedChildrenCompanion(
                userId: userId,
                id: id,
                nickname: nickname,
                birthDate: birthDate,
                ageBand: ageBand,
                gender: gender,
                intro: intro,
                interestsJson: interestsJson,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int userId,
                required int id,
                required String nickname,
                Value<String?> birthDate = const Value.absent(),
                Value<String> ageBand = const Value.absent(),
                Value<String> gender = const Value.absent(),
                Value<String?> intro = const Value.absent(),
                Value<String> interestsJson = const Value.absent(),
                required DateTime syncedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedChildrenCompanion.insert(
                userId: userId,
                id: id,
                nickname: nickname,
                birthDate: birthDate,
                ageBand: ageBand,
                gender: gender,
                intro: intro,
                interestsJson: interestsJson,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedChildrenTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedChildrenTable,
      CachedChildrenData,
      $$CachedChildrenTableFilterComposer,
      $$CachedChildrenTableOrderingComposer,
      $$CachedChildrenTableAnnotationComposer,
      $$CachedChildrenTableCreateCompanionBuilder,
      $$CachedChildrenTableUpdateCompanionBuilder,
      (
        CachedChildrenData,
        BaseReferences<_$AppDatabase, $CachedChildrenTable, CachedChildrenData>,
      ),
      CachedChildrenData,
      PrefetchHooks Function()
    >;
typedef $$CachedCharactersTableCreateCompanionBuilder =
    CachedCharactersCompanion Function({
      required int userId,
      required int id,
      required String kind,
      required String name,
      Value<int?> relatedChildId,
      Value<String?> relation,
      Value<String?> note,
      Value<int?> listenerChildId,
      Value<bool> enabled,
      required DateTime syncedAt,
      Value<int> rowid,
    });
typedef $$CachedCharactersTableUpdateCompanionBuilder =
    CachedCharactersCompanion Function({
      Value<int> userId,
      Value<int> id,
      Value<String> kind,
      Value<String> name,
      Value<int?> relatedChildId,
      Value<String?> relation,
      Value<String?> note,
      Value<int?> listenerChildId,
      Value<bool> enabled,
      Value<DateTime> syncedAt,
      Value<int> rowid,
    });

class $$CachedCharactersTableFilterComposer
    extends Composer<_$AppDatabase, $CachedCharactersTable> {
  $$CachedCharactersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get relatedChildId => $composableBuilder(
    column: $table.relatedChildId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relation => $composableBuilder(
    column: $table.relation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get listenerChildId => $composableBuilder(
    column: $table.listenerChildId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedCharactersTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedCharactersTable> {
  $$CachedCharactersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get relatedChildId => $composableBuilder(
    column: $table.relatedChildId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relation => $composableBuilder(
    column: $table.relation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get listenerChildId => $composableBuilder(
    column: $table.listenerChildId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedCharactersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedCharactersTable> {
  $$CachedCharactersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get relatedChildId => $composableBuilder(
    column: $table.relatedChildId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relation =>
      $composableBuilder(column: $table.relation, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get listenerChildId => $composableBuilder(
    column: $table.listenerChildId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$CachedCharactersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedCharactersTable,
          CachedCharacter,
          $$CachedCharactersTableFilterComposer,
          $$CachedCharactersTableOrderingComposer,
          $$CachedCharactersTableAnnotationComposer,
          $$CachedCharactersTableCreateCompanionBuilder,
          $$CachedCharactersTableUpdateCompanionBuilder,
          (
            CachedCharacter,
            BaseReferences<
              _$AppDatabase,
              $CachedCharactersTable,
              CachedCharacter
            >,
          ),
          CachedCharacter,
          PrefetchHooks Function()
        > {
  $$CachedCharactersTableTableManager(
    _$AppDatabase db,
    $CachedCharactersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedCharactersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedCharactersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedCharactersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> userId = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> relatedChildId = const Value.absent(),
                Value<String?> relation = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> listenerChildId = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCharactersCompanion(
                userId: userId,
                id: id,
                kind: kind,
                name: name,
                relatedChildId: relatedChildId,
                relation: relation,
                note: note,
                listenerChildId: listenerChildId,
                enabled: enabled,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int userId,
                required int id,
                required String kind,
                required String name,
                Value<int?> relatedChildId = const Value.absent(),
                Value<String?> relation = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> listenerChildId = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                required DateTime syncedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedCharactersCompanion.insert(
                userId: userId,
                id: id,
                kind: kind,
                name: name,
                relatedChildId: relatedChildId,
                relation: relation,
                note: note,
                listenerChildId: listenerChildId,
                enabled: enabled,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedCharactersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedCharactersTable,
      CachedCharacter,
      $$CachedCharactersTableFilterComposer,
      $$CachedCharactersTableOrderingComposer,
      $$CachedCharactersTableAnnotationComposer,
      $$CachedCharactersTableCreateCompanionBuilder,
      $$CachedCharactersTableUpdateCompanionBuilder,
      (
        CachedCharacter,
        BaseReferences<_$AppDatabase, $CachedCharactersTable, CachedCharacter>,
      ),
      CachedCharacter,
      PrefetchHooks Function()
    >;
typedef $$CachedVoicesTableCreateCompanionBuilder =
    CachedVoicesCompanion Function({
      required int userId,
      required int id,
      required String name,
      Value<String> kind,
      Value<String> language,
      Value<String> provider,
      Value<String> providerVoiceId,
      Value<String?> speechModel,
      Value<String> speedTier,
      Value<double> speed,
      Value<bool> enabled,
      Value<String?> description,
      Value<int> sortOrder,
      Value<String?> previewAudioUrl,
      required DateTime syncedAt,
      Value<int> rowid,
    });
typedef $$CachedVoicesTableUpdateCompanionBuilder =
    CachedVoicesCompanion Function({
      Value<int> userId,
      Value<int> id,
      Value<String> name,
      Value<String> kind,
      Value<String> language,
      Value<String> provider,
      Value<String> providerVoiceId,
      Value<String?> speechModel,
      Value<String> speedTier,
      Value<double> speed,
      Value<bool> enabled,
      Value<String?> description,
      Value<int> sortOrder,
      Value<String?> previewAudioUrl,
      Value<DateTime> syncedAt,
      Value<int> rowid,
    });

class $$CachedVoicesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedVoicesTable> {
  $$CachedVoicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerVoiceId => $composableBuilder(
    column: $table.providerVoiceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speechModel => $composableBuilder(
    column: $table.speechModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speedTier => $composableBuilder(
    column: $table.speedTier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previewAudioUrl => $composableBuilder(
    column: $table.previewAudioUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedVoicesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedVoicesTable> {
  $$CachedVoicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerVoiceId => $composableBuilder(
    column: $table.providerVoiceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speechModel => $composableBuilder(
    column: $table.speechModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speedTier => $composableBuilder(
    column: $table.speedTier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previewAudioUrl => $composableBuilder(
    column: $table.previewAudioUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedVoicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedVoicesTable> {
  $$CachedVoicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get providerVoiceId => $composableBuilder(
    column: $table.providerVoiceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get speechModel => $composableBuilder(
    column: $table.speechModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get speedTier =>
      $composableBuilder(column: $table.speedTier, builder: (column) => column);

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get previewAudioUrl => $composableBuilder(
    column: $table.previewAudioUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$CachedVoicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedVoicesTable,
          CachedVoice,
          $$CachedVoicesTableFilterComposer,
          $$CachedVoicesTableOrderingComposer,
          $$CachedVoicesTableAnnotationComposer,
          $$CachedVoicesTableCreateCompanionBuilder,
          $$CachedVoicesTableUpdateCompanionBuilder,
          (
            CachedVoice,
            BaseReferences<_$AppDatabase, $CachedVoicesTable, CachedVoice>,
          ),
          CachedVoice,
          PrefetchHooks Function()
        > {
  $$CachedVoicesTableTableManager(_$AppDatabase db, $CachedVoicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedVoicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedVoicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedVoicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> userId = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> providerVoiceId = const Value.absent(),
                Value<String?> speechModel = const Value.absent(),
                Value<String> speedTier = const Value.absent(),
                Value<double> speed = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> previewAudioUrl = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedVoicesCompanion(
                userId: userId,
                id: id,
                name: name,
                kind: kind,
                language: language,
                provider: provider,
                providerVoiceId: providerVoiceId,
                speechModel: speechModel,
                speedTier: speedTier,
                speed: speed,
                enabled: enabled,
                description: description,
                sortOrder: sortOrder,
                previewAudioUrl: previewAudioUrl,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int userId,
                required int id,
                required String name,
                Value<String> kind = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> providerVoiceId = const Value.absent(),
                Value<String?> speechModel = const Value.absent(),
                Value<String> speedTier = const Value.absent(),
                Value<double> speed = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> previewAudioUrl = const Value.absent(),
                required DateTime syncedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedVoicesCompanion.insert(
                userId: userId,
                id: id,
                name: name,
                kind: kind,
                language: language,
                provider: provider,
                providerVoiceId: providerVoiceId,
                speechModel: speechModel,
                speedTier: speedTier,
                speed: speed,
                enabled: enabled,
                description: description,
                sortOrder: sortOrder,
                previewAudioUrl: previewAudioUrl,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedVoicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedVoicesTable,
      CachedVoice,
      $$CachedVoicesTableFilterComposer,
      $$CachedVoicesTableOrderingComposer,
      $$CachedVoicesTableAnnotationComposer,
      $$CachedVoicesTableCreateCompanionBuilder,
      $$CachedVoicesTableUpdateCompanionBuilder,
      (
        CachedVoice,
        BaseReferences<_$AppDatabase, $CachedVoicesTable, CachedVoice>,
      ),
      CachedVoice,
      PrefetchHooks Function()
    >;
typedef $$CachedVoicePrefsTableCreateCompanionBuilder =
    CachedVoicePrefsCompanion Function({
      required int userId,
      required int childId,
      Value<String> speedTier,
      Value<String> tonePreset,
      Value<bool> likenessBoost,
      Value<int?> defaultVoiceId,
      required DateTime syncedAt,
      Value<int> rowid,
    });
typedef $$CachedVoicePrefsTableUpdateCompanionBuilder =
    CachedVoicePrefsCompanion Function({
      Value<int> userId,
      Value<int> childId,
      Value<String> speedTier,
      Value<String> tonePreset,
      Value<bool> likenessBoost,
      Value<int?> defaultVoiceId,
      Value<DateTime> syncedAt,
      Value<int> rowid,
    });

class $$CachedVoicePrefsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedVoicePrefsTable> {
  $$CachedVoicePrefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get childId => $composableBuilder(
    column: $table.childId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speedTier => $composableBuilder(
    column: $table.speedTier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tonePreset => $composableBuilder(
    column: $table.tonePreset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get likenessBoost => $composableBuilder(
    column: $table.likenessBoost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultVoiceId => $composableBuilder(
    column: $table.defaultVoiceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedVoicePrefsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedVoicePrefsTable> {
  $$CachedVoicePrefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get childId => $composableBuilder(
    column: $table.childId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speedTier => $composableBuilder(
    column: $table.speedTier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tonePreset => $composableBuilder(
    column: $table.tonePreset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get likenessBoost => $composableBuilder(
    column: $table.likenessBoost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultVoiceId => $composableBuilder(
    column: $table.defaultVoiceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedVoicePrefsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedVoicePrefsTable> {
  $$CachedVoicePrefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get childId =>
      $composableBuilder(column: $table.childId, builder: (column) => column);

  GeneratedColumn<String> get speedTier =>
      $composableBuilder(column: $table.speedTier, builder: (column) => column);

  GeneratedColumn<String> get tonePreset => $composableBuilder(
    column: $table.tonePreset,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get likenessBoost => $composableBuilder(
    column: $table.likenessBoost,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultVoiceId => $composableBuilder(
    column: $table.defaultVoiceId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$CachedVoicePrefsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedVoicePrefsTable,
          CachedVoicePref,
          $$CachedVoicePrefsTableFilterComposer,
          $$CachedVoicePrefsTableOrderingComposer,
          $$CachedVoicePrefsTableAnnotationComposer,
          $$CachedVoicePrefsTableCreateCompanionBuilder,
          $$CachedVoicePrefsTableUpdateCompanionBuilder,
          (
            CachedVoicePref,
            BaseReferences<
              _$AppDatabase,
              $CachedVoicePrefsTable,
              CachedVoicePref
            >,
          ),
          CachedVoicePref,
          PrefetchHooks Function()
        > {
  $$CachedVoicePrefsTableTableManager(
    _$AppDatabase db,
    $CachedVoicePrefsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedVoicePrefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedVoicePrefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedVoicePrefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> userId = const Value.absent(),
                Value<int> childId = const Value.absent(),
                Value<String> speedTier = const Value.absent(),
                Value<String> tonePreset = const Value.absent(),
                Value<bool> likenessBoost = const Value.absent(),
                Value<int?> defaultVoiceId = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedVoicePrefsCompanion(
                userId: userId,
                childId: childId,
                speedTier: speedTier,
                tonePreset: tonePreset,
                likenessBoost: likenessBoost,
                defaultVoiceId: defaultVoiceId,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int userId,
                required int childId,
                Value<String> speedTier = const Value.absent(),
                Value<String> tonePreset = const Value.absent(),
                Value<bool> likenessBoost = const Value.absent(),
                Value<int?> defaultVoiceId = const Value.absent(),
                required DateTime syncedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedVoicePrefsCompanion.insert(
                userId: userId,
                childId: childId,
                speedTier: speedTier,
                tonePreset: tonePreset,
                likenessBoost: likenessBoost,
                defaultVoiceId: defaultVoiceId,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedVoicePrefsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedVoicePrefsTable,
      CachedVoicePref,
      $$CachedVoicePrefsTableFilterComposer,
      $$CachedVoicePrefsTableOrderingComposer,
      $$CachedVoicePrefsTableAnnotationComposer,
      $$CachedVoicePrefsTableCreateCompanionBuilder,
      $$CachedVoicePrefsTableUpdateCompanionBuilder,
      (
        CachedVoicePref,
        BaseReferences<_$AppDatabase, $CachedVoicePrefsTable, CachedVoicePref>,
      ),
      CachedVoicePref,
      PrefetchHooks Function()
    >;
typedef $$AccountSnapshotsTableCreateCompanionBuilder =
    AccountSnapshotsCompanion Function({
      Value<int> userId,
      Value<String?> displayName,
      Value<String> preferredLanguage,
      Value<String?> quotaMonth,
      Value<int> storyUsed,
      Value<int> storyLimit,
      Value<int> cloneUsed,
      Value<int> cloneLimit,
      required DateTime syncedAt,
    });
typedef $$AccountSnapshotsTableUpdateCompanionBuilder =
    AccountSnapshotsCompanion Function({
      Value<int> userId,
      Value<String?> displayName,
      Value<String> preferredLanguage,
      Value<String?> quotaMonth,
      Value<int> storyUsed,
      Value<int> storyLimit,
      Value<int> cloneUsed,
      Value<int> cloneLimit,
      Value<DateTime> syncedAt,
    });

class $$AccountSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountSnapshotsTable> {
  $$AccountSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredLanguage => $composableBuilder(
    column: $table.preferredLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quotaMonth => $composableBuilder(
    column: $table.quotaMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storyUsed => $composableBuilder(
    column: $table.storyUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storyLimit => $composableBuilder(
    column: $table.storyLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cloneUsed => $composableBuilder(
    column: $table.cloneUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cloneLimit => $composableBuilder(
    column: $table.cloneLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountSnapshotsTable> {
  $$AccountSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredLanguage => $composableBuilder(
    column: $table.preferredLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quotaMonth => $composableBuilder(
    column: $table.quotaMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storyUsed => $composableBuilder(
    column: $table.storyUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storyLimit => $composableBuilder(
    column: $table.storyLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cloneUsed => $composableBuilder(
    column: $table.cloneUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cloneLimit => $composableBuilder(
    column: $table.cloneLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountSnapshotsTable> {
  $$AccountSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredLanguage => $composableBuilder(
    column: $table.preferredLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quotaMonth => $composableBuilder(
    column: $table.quotaMonth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get storyUsed =>
      $composableBuilder(column: $table.storyUsed, builder: (column) => column);

  GeneratedColumn<int> get storyLimit => $composableBuilder(
    column: $table.storyLimit,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cloneUsed =>
      $composableBuilder(column: $table.cloneUsed, builder: (column) => column);

  GeneratedColumn<int> get cloneLimit => $composableBuilder(
    column: $table.cloneLimit,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$AccountSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountSnapshotsTable,
          AccountSnapshot,
          $$AccountSnapshotsTableFilterComposer,
          $$AccountSnapshotsTableOrderingComposer,
          $$AccountSnapshotsTableAnnotationComposer,
          $$AccountSnapshotsTableCreateCompanionBuilder,
          $$AccountSnapshotsTableUpdateCompanionBuilder,
          (
            AccountSnapshot,
            BaseReferences<
              _$AppDatabase,
              $AccountSnapshotsTable,
              AccountSnapshot
            >,
          ),
          AccountSnapshot,
          PrefetchHooks Function()
        > {
  $$AccountSnapshotsTableTableManager(
    _$AppDatabase db,
    $AccountSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> userId = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String> preferredLanguage = const Value.absent(),
                Value<String?> quotaMonth = const Value.absent(),
                Value<int> storyUsed = const Value.absent(),
                Value<int> storyLimit = const Value.absent(),
                Value<int> cloneUsed = const Value.absent(),
                Value<int> cloneLimit = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
              }) => AccountSnapshotsCompanion(
                userId: userId,
                displayName: displayName,
                preferredLanguage: preferredLanguage,
                quotaMonth: quotaMonth,
                storyUsed: storyUsed,
                storyLimit: storyLimit,
                cloneUsed: cloneUsed,
                cloneLimit: cloneLimit,
                syncedAt: syncedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> userId = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String> preferredLanguage = const Value.absent(),
                Value<String?> quotaMonth = const Value.absent(),
                Value<int> storyUsed = const Value.absent(),
                Value<int> storyLimit = const Value.absent(),
                Value<int> cloneUsed = const Value.absent(),
                Value<int> cloneLimit = const Value.absent(),
                required DateTime syncedAt,
              }) => AccountSnapshotsCompanion.insert(
                userId: userId,
                displayName: displayName,
                preferredLanguage: preferredLanguage,
                quotaMonth: quotaMonth,
                storyUsed: storyUsed,
                storyLimit: storyLimit,
                cloneUsed: cloneUsed,
                cloneLimit: cloneLimit,
                syncedAt: syncedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountSnapshotsTable,
      AccountSnapshot,
      $$AccountSnapshotsTableFilterComposer,
      $$AccountSnapshotsTableOrderingComposer,
      $$AccountSnapshotsTableAnnotationComposer,
      $$AccountSnapshotsTableCreateCompanionBuilder,
      $$AccountSnapshotsTableUpdateCompanionBuilder,
      (
        AccountSnapshot,
        BaseReferences<_$AppDatabase, $AccountSnapshotsTable, AccountSnapshot>,
      ),
      AccountSnapshot,
      PrefetchHooks Function()
    >;
typedef $$MediaFilesTableCreateCompanionBuilder =
    MediaFilesCompanion Function({
      required int userId,
      required int storyId,
      required String localPath,
      Value<int> sizeBytes,
      Value<DateTime?> lastPlayedAt,
      Value<bool> ready,
      Value<int> rowid,
    });
typedef $$MediaFilesTableUpdateCompanionBuilder =
    MediaFilesCompanion Function({
      Value<int> userId,
      Value<int> storyId,
      Value<String> localPath,
      Value<int> sizeBytes,
      Value<DateTime?> lastPlayedAt,
      Value<bool> ready,
      Value<int> rowid,
    });

class $$MediaFilesTableFilterComposer
    extends Composer<_$AppDatabase, $MediaFilesTable> {
  $$MediaFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storyId => $composableBuilder(
    column: $table.storyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ready => $composableBuilder(
    column: $table.ready,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MediaFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaFilesTable> {
  $$MediaFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storyId => $composableBuilder(
    column: $table.storyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ready => $composableBuilder(
    column: $table.ready,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaFilesTable> {
  $$MediaFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get storyId =>
      $composableBuilder(column: $table.storyId, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get ready =>
      $composableBuilder(column: $table.ready, builder: (column) => column);
}

class $$MediaFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MediaFilesTable,
          MediaFile,
          $$MediaFilesTableFilterComposer,
          $$MediaFilesTableOrderingComposer,
          $$MediaFilesTableAnnotationComposer,
          $$MediaFilesTableCreateCompanionBuilder,
          $$MediaFilesTableUpdateCompanionBuilder,
          (
            MediaFile,
            BaseReferences<_$AppDatabase, $MediaFilesTable, MediaFile>,
          ),
          MediaFile,
          PrefetchHooks Function()
        > {
  $$MediaFilesTableTableManager(_$AppDatabase db, $MediaFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> userId = const Value.absent(),
                Value<int> storyId = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<bool> ready = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaFilesCompanion(
                userId: userId,
                storyId: storyId,
                localPath: localPath,
                sizeBytes: sizeBytes,
                lastPlayedAt: lastPlayedAt,
                ready: ready,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int userId,
                required int storyId,
                required String localPath,
                Value<int> sizeBytes = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<bool> ready = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaFilesCompanion.insert(
                userId: userId,
                storyId: storyId,
                localPath: localPath,
                sizeBytes: sizeBytes,
                lastPlayedAt: lastPlayedAt,
                ready: ready,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MediaFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MediaFilesTable,
      MediaFile,
      $$MediaFilesTableFilterComposer,
      $$MediaFilesTableOrderingComposer,
      $$MediaFilesTableAnnotationComposer,
      $$MediaFilesTableCreateCompanionBuilder,
      $$MediaFilesTableUpdateCompanionBuilder,
      (MediaFile, BaseReferences<_$AppDatabase, $MediaFilesTable, MediaFile>),
      MediaFile,
      PrefetchHooks Function()
    >;
typedef $$PlaybackProgressTableCreateCompanionBuilder =
    PlaybackProgressCompanion Function({
      required int userId,
      required int storyId,
      Value<int> positionMs,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PlaybackProgressTableUpdateCompanionBuilder =
    PlaybackProgressCompanion Function({
      Value<int> userId,
      Value<int> storyId,
      Value<int> positionMs,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PlaybackProgressTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackProgressTable> {
  $$PlaybackProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storyId => $composableBuilder(
    column: $table.storyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaybackProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackProgressTable> {
  $$PlaybackProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storyId => $composableBuilder(
    column: $table.storyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackProgressTable> {
  $$PlaybackProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get storyId =>
      $composableBuilder(column: $table.storyId, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlaybackProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackProgressTable,
          PlaybackProgressData,
          $$PlaybackProgressTableFilterComposer,
          $$PlaybackProgressTableOrderingComposer,
          $$PlaybackProgressTableAnnotationComposer,
          $$PlaybackProgressTableCreateCompanionBuilder,
          $$PlaybackProgressTableUpdateCompanionBuilder,
          (
            PlaybackProgressData,
            BaseReferences<
              _$AppDatabase,
              $PlaybackProgressTable,
              PlaybackProgressData
            >,
          ),
          PlaybackProgressData,
          PrefetchHooks Function()
        > {
  $$PlaybackProgressTableTableManager(
    _$AppDatabase db,
    $PlaybackProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> userId = const Value.absent(),
                Value<int> storyId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackProgressCompanion(
                userId: userId,
                storyId: storyId,
                positionMs: positionMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int userId,
                required int storyId,
                Value<int> positionMs = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlaybackProgressCompanion.insert(
                userId: userId,
                storyId: storyId,
                positionMs: positionMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaybackProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackProgressTable,
      PlaybackProgressData,
      $$PlaybackProgressTableFilterComposer,
      $$PlaybackProgressTableOrderingComposer,
      $$PlaybackProgressTableAnnotationComposer,
      $$PlaybackProgressTableCreateCompanionBuilder,
      $$PlaybackProgressTableUpdateCompanionBuilder,
      (
        PlaybackProgressData,
        BaseReferences<
          _$AppDatabase,
          $PlaybackProgressTable,
          PlaybackProgressData
        >,
      ),
      PlaybackProgressData,
      PrefetchHooks Function()
    >;
typedef $$StoryFavoritesTableCreateCompanionBuilder =
    StoryFavoritesCompanion Function({
      required int userId,
      required int storyId,
      required DateTime favoritedAt,
      Value<int> rowid,
    });
typedef $$StoryFavoritesTableUpdateCompanionBuilder =
    StoryFavoritesCompanion Function({
      Value<int> userId,
      Value<int> storyId,
      Value<DateTime> favoritedAt,
      Value<int> rowid,
    });

class $$StoryFavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $StoryFavoritesTable> {
  $$StoryFavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storyId => $composableBuilder(
    column: $table.storyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoryFavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $StoryFavoritesTable> {
  $$StoryFavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storyId => $composableBuilder(
    column: $table.storyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoryFavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoryFavoritesTable> {
  $$StoryFavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get storyId =>
      $composableBuilder(column: $table.storyId, builder: (column) => column);

  GeneratedColumn<DateTime> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => column,
  );
}

class $$StoryFavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoryFavoritesTable,
          StoryFavorite,
          $$StoryFavoritesTableFilterComposer,
          $$StoryFavoritesTableOrderingComposer,
          $$StoryFavoritesTableAnnotationComposer,
          $$StoryFavoritesTableCreateCompanionBuilder,
          $$StoryFavoritesTableUpdateCompanionBuilder,
          (
            StoryFavorite,
            BaseReferences<_$AppDatabase, $StoryFavoritesTable, StoryFavorite>,
          ),
          StoryFavorite,
          PrefetchHooks Function()
        > {
  $$StoryFavoritesTableTableManager(
    _$AppDatabase db,
    $StoryFavoritesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoryFavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoryFavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoryFavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> userId = const Value.absent(),
                Value<int> storyId = const Value.absent(),
                Value<DateTime> favoritedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoryFavoritesCompanion(
                userId: userId,
                storyId: storyId,
                favoritedAt: favoritedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int userId,
                required int storyId,
                required DateTime favoritedAt,
                Value<int> rowid = const Value.absent(),
              }) => StoryFavoritesCompanion.insert(
                userId: userId,
                storyId: storyId,
                favoritedAt: favoritedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoryFavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoryFavoritesTable,
      StoryFavorite,
      $$StoryFavoritesTableFilterComposer,
      $$StoryFavoritesTableOrderingComposer,
      $$StoryFavoritesTableAnnotationComposer,
      $$StoryFavoritesTableCreateCompanionBuilder,
      $$StoryFavoritesTableUpdateCompanionBuilder,
      (
        StoryFavorite,
        BaseReferences<_$AppDatabase, $StoryFavoritesTable, StoryFavorite>,
      ),
      StoryFavorite,
      PrefetchHooks Function()
    >;
typedef $$MoodEntriesTableCreateCompanionBuilder =
    MoodEntriesCompanion Function({
      required int userId,
      required String dayKey,
      required int childId,
      Value<String> mood,
      Value<String?> note,
      Value<int?> storyId,
      Value<int> rowid,
    });
typedef $$MoodEntriesTableUpdateCompanionBuilder =
    MoodEntriesCompanion Function({
      Value<int> userId,
      Value<String> dayKey,
      Value<int> childId,
      Value<String> mood,
      Value<String?> note,
      Value<int?> storyId,
      Value<int> rowid,
    });

class $$MoodEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MoodEntriesTable> {
  $$MoodEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get childId => $composableBuilder(
    column: $table.childId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storyId => $composableBuilder(
    column: $table.storyId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MoodEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MoodEntriesTable> {
  $$MoodEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get childId => $composableBuilder(
    column: $table.childId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storyId => $composableBuilder(
    column: $table.storyId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MoodEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MoodEntriesTable> {
  $$MoodEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<int> get childId =>
      $composableBuilder(column: $table.childId, builder: (column) => column);

  GeneratedColumn<String> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get storyId =>
      $composableBuilder(column: $table.storyId, builder: (column) => column);
}

class $$MoodEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MoodEntriesTable,
          MoodEntry,
          $$MoodEntriesTableFilterComposer,
          $$MoodEntriesTableOrderingComposer,
          $$MoodEntriesTableAnnotationComposer,
          $$MoodEntriesTableCreateCompanionBuilder,
          $$MoodEntriesTableUpdateCompanionBuilder,
          (
            MoodEntry,
            BaseReferences<_$AppDatabase, $MoodEntriesTable, MoodEntry>,
          ),
          MoodEntry,
          PrefetchHooks Function()
        > {
  $$MoodEntriesTableTableManager(_$AppDatabase db, $MoodEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MoodEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MoodEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MoodEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> userId = const Value.absent(),
                Value<String> dayKey = const Value.absent(),
                Value<int> childId = const Value.absent(),
                Value<String> mood = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> storyId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MoodEntriesCompanion(
                userId: userId,
                dayKey: dayKey,
                childId: childId,
                mood: mood,
                note: note,
                storyId: storyId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int userId,
                required String dayKey,
                required int childId,
                Value<String> mood = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> storyId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MoodEntriesCompanion.insert(
                userId: userId,
                dayKey: dayKey,
                childId: childId,
                mood: mood,
                note: note,
                storyId: storyId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MoodEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MoodEntriesTable,
      MoodEntry,
      $$MoodEntriesTableFilterComposer,
      $$MoodEntriesTableOrderingComposer,
      $$MoodEntriesTableAnnotationComposer,
      $$MoodEntriesTableCreateCompanionBuilder,
      $$MoodEntriesTableUpdateCompanionBuilder,
      (MoodEntry, BaseReferences<_$AppDatabase, $MoodEntriesTable, MoodEntry>),
      MoodEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedStoriesTableTableManager get cachedStories =>
      $$CachedStoriesTableTableManager(_db, _db.cachedStories);
  $$CachedChildrenTableTableManager get cachedChildren =>
      $$CachedChildrenTableTableManager(_db, _db.cachedChildren);
  $$CachedCharactersTableTableManager get cachedCharacters =>
      $$CachedCharactersTableTableManager(_db, _db.cachedCharacters);
  $$CachedVoicesTableTableManager get cachedVoices =>
      $$CachedVoicesTableTableManager(_db, _db.cachedVoices);
  $$CachedVoicePrefsTableTableManager get cachedVoicePrefs =>
      $$CachedVoicePrefsTableTableManager(_db, _db.cachedVoicePrefs);
  $$AccountSnapshotsTableTableManager get accountSnapshots =>
      $$AccountSnapshotsTableTableManager(_db, _db.accountSnapshots);
  $$MediaFilesTableTableManager get mediaFiles =>
      $$MediaFilesTableTableManager(_db, _db.mediaFiles);
  $$PlaybackProgressTableTableManager get playbackProgress =>
      $$PlaybackProgressTableTableManager(_db, _db.playbackProgress);
  $$StoryFavoritesTableTableManager get storyFavorites =>
      $$StoryFavoritesTableTableManager(_db, _db.storyFavorites);
  $$MoodEntriesTableTableManager get moodEntries =>
      $$MoodEntriesTableTableManager(_db, _db.moodEntries);
}
