// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '呼呼 · 枕边故事';

  @override
  String get meTitle => '我的';

  @override
  String get tabStories => '故事';

  @override
  String get meSettings => '设置';

  @override
  String get meVoicesTitle => '音色管理';

  @override
  String get meVoicesSubtitleClone => '系统音色与家长声音克隆';

  @override
  String get meVoicesSubtitle => '系统朗读音色';

  @override
  String get meCharactersTitle => '角色管理';

  @override
  String get meCharactersSubtitle => '小听众档案与故事角色';

  @override
  String get meLanguageTitle => '语言';

  @override
  String meLanguageSubtitle(String label) {
    return '$label';
  }

  @override
  String get meAboutTitle => '关于';

  @override
  String get meAboutSubtitle => '产品与联系方式';

  @override
  String get meTermsTitle => '用户协议';

  @override
  String get meTermsSubtitle => '使用条款';

  @override
  String get mePrivacyTitle => '隐私政策';

  @override
  String get mePrivacySubtitle => '我们如何处理你的数据';

  @override
  String meVersion(String version) {
    return 'Version $version';
  }

  @override
  String get meLogoutAccount => '退出当前账号';

  @override
  String meBrandFooter(String version) {
    return '呼呼 · 枕边故事  版本v$version';
  }

  @override
  String get languagePickerTitle => '语言';

  @override
  String get languageZhHans => '简体中文';

  @override
  String get languageZhHant => '繁體中文';

  @override
  String get languageEn => 'English';

  @override
  String get profileGuest => '未登录';

  @override
  String get profileGuestHint => '登录后可同步故事与音色';

  @override
  String get profileConnected => '已连接枕边故事服务';

  @override
  String get profileDefaultName => '枕边家长';

  @override
  String get profileLogin => '登录';

  @override
  String get profileLogout => '退出';

  @override
  String get profileRefresh => '刷新';

  @override
  String quotaStories(Object used, Object limit) {
    return '本月故事 $used/$limit';
  }

  @override
  String quotaCloneSuffix(Object used, Object limit) {
    return ' · 克隆 $used/$limit';
  }

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutTagline => '为孩子编织温柔的枕边故事';

  @override
  String get aboutVersionLabel => '版本';

  @override
  String get aboutDeveloperLabel => '开发者';

  @override
  String get aboutDeveloperName => '风息谷工作室';

  @override
  String get aboutSupportLabel => '支持';

  @override
  String get aboutWebsiteLabel => '网站';

  @override
  String get aboutTermsLink => '用户协议';

  @override
  String get aboutPrivacyLink => '隐私政策';

  @override
  String aboutCopyright(int year) {
    return '© $year Lullvale';
  }

  @override
  String get termsTitle => '用户协议';

  @override
  String get privacyTitle => '隐私政策';

  @override
  String get legalOpenFailed => '无法打开链接。';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '确定';

  @override
  String get commonDelete => '删除';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonCreate => '创建';

  @override
  String get commonSave => '保存';

  @override
  String get commonClose => '关闭';

  @override
  String get commonUnnamed => '未命名';

  @override
  String get commonLoading => '加载中';

  @override
  String get genderUnspecified => '不指定';

  @override
  String get genderBoy => '男孩';

  @override
  String get genderGirl => '女孩';

  @override
  String get genderOther => '其他';

  @override
  String get homeOfflineSnackbar => '离线模式：显示本地缓存，联网后自动同步';

  @override
  String get authBrandName => '呼呼';

  @override
  String get authBrandBadge => '枕边故事';

  @override
  String get authSubtitleLogin => '登录后继续枕边故事';

  @override
  String get authSubtitleRegister => '使用邀请码创建账号';

  @override
  String get authInviteCode => '邀请码';

  @override
  String get authNicknameOptional => '昵称（可选）';

  @override
  String get authPhone => '手机号';

  @override
  String get authPassword => '密码';

  @override
  String get authConfirmPassword => '确认密码';

  @override
  String get authShowPassword => '显示密码';

  @override
  String get authHidePassword => '隐藏密码';

  @override
  String get authLoginSms => '验证码登录';

  @override
  String get authForgotPassword => '忘记密码？';

  @override
  String get authSubmitLogin => '登录';

  @override
  String get authSubmitRegister => '注册并登录';

  @override
  String get authHaveAccount => '已有账号？ ';

  @override
  String get authHaveInvite => '有邀请码？ ';

  @override
  String get authGoLogin => '去登录';

  @override
  String get authGoRegister => '去注册';

  @override
  String get authNightHint => '夜间低蓝光护眼设计 · 愿你今晚有好梦';

  @override
  String get authAgreeRegisterPrefix => '注册即代表同意 ';

  @override
  String get authAgreeLoginPrefix => '登录即代表您已同意 ';

  @override
  String get authTermsLink => '用户协议';

  @override
  String get authAnd => ' 与 ';

  @override
  String get authPrivacyLink => '隐私政策';

  @override
  String get authPrivacyLinkRegister => '隐私保护政策';

  @override
  String get authErrorInviteRequired => '请填写邀请码';

  @override
  String get authErrorPhoneRequired => '请填写手机号';

  @override
  String get authErrorPasswordShort => '密码至少 8 位';

  @override
  String get authErrorPasswordMismatch => '两次输入的密码不一致';

  @override
  String get authErrorPasswordRequired => '请填写密码';

  @override
  String get authErrorInvalidResponse => '登录响应无效';

  @override
  String authComingSoon(String feature) {
    return '$feature暂未开放，敬请期待';
  }

  @override
  String get authFeatureSmsLogin => '验证码登录';

  @override
  String get authFeatureRecoverPassword => '找回密码';

  @override
  String get authClose => '关闭';

  @override
  String get storyProgressQueued => '排队中…';

  @override
  String get storyProgressSeriesOutline => '正在构思系列大纲…';

  @override
  String get storyProgressEpisodePlan => '正在构思今晚情节…';

  @override
  String get storyProgressDraft => '正在写故事正文…';

  @override
  String get storyProgressTts => '正在生成朗读音频…';

  @override
  String get storyProgressReady => '完成';

  @override
  String get storyProgressReadyPlay => '完成，准备播放…';

  @override
  String get storyProgressFailed => '生成失败';

  @override
  String storyProgressGenerating(String progress) {
    return '生成中（$progress）…';
  }

  @override
  String get storyGenerateFailed => '故事生成失败';

  @override
  String get storyGenerateFailedRetry => '故事生成失败，可点重试';

  @override
  String get storyStillGenerating => '故事还在生成中，请下拉刷新后再听';

  @override
  String get storyNoAudio => '暂无音频，无法播放';

  @override
  String get storyNoAudioShort => '暂无音频';

  @override
  String get storyCreateFailed => '故事创建失败';

  @override
  String get storyRetrying => '正在重新生成…';

  @override
  String get storyResumeWaiting => '继续等待生成…';

  @override
  String get storyContinueWaiting => '继续等待';

  @override
  String get storyContinuingEpisode => '正在续写下一集…';

  @override
  String get storySubmittedQueued => '已提交，排队中…';

  @override
  String get storiesTitle => '故事';

  @override
  String get storiesStatusWaitingFirst => '等待第一篇';

  @override
  String get storiesStatusReady => '夜光模式已就绪';

  @override
  String get storiesCreateEyebrow => '织梦引擎 · 新章';

  @override
  String get storiesCreateTitle => '创作今晚的故事';

  @override
  String get storiesCreateSubtitle => '定制专属角色、故事情节与助眠音画';

  @override
  String get storiesLibraryTitle => '枕边故事宝盒';

  @override
  String get storiesLibraryEmpty => '暂无故事';

  @override
  String storiesLibraryCount(int count) {
    return '按时间倒序 · $count 篇';
  }

  @override
  String get storiesEmptyShelfTitle => '空空的书架';

  @override
  String get storiesEmptyShelfBody => '今晚的第一本小书，还在等你点上方金色卡片。';

  @override
  String get storiesUntitled => '未完成的故事';

  @override
  String get storiesFailedRetry => '生成失败 · 可重试';

  @override
  String storiesFailedWithError(String error) {
    return '失败 · $error';
  }

  @override
  String get storiesSeriesContinueHint => '系列续写请从「创作」页重新开始';

  @override
  String storiesMinutes(Object minutes) {
    return '$minutes 分钟';
  }

  @override
  String storiesSeriesMeta(Object id) {
    return '系列 #$id';
  }

  @override
  String storiesEpisodeMeta(Object ep) {
    return ' 第$ep集';
  }

  @override
  String get creatingTitle => '创作中';

  @override
  String get creatingBackTooltip => '返回故事列表';

  @override
  String get creatingHeadlineOk => '正在为今晚写故事';

  @override
  String get creatingHeadlineFail => '这次没能完成';

  @override
  String get creatingBodyOk => '云端正在写正文并录制朗读，通常需要一两分钟。';

  @override
  String get creatingBodyFail => '可以重试，或先回列表，稍后再打开这篇故事。';

  @override
  String get creatingHintsOkTitle => '生成时你可以';

  @override
  String get creatingHintsFailTitle => '接下来可以';

  @override
  String get creatingHintAutoPlay => '完成后会自动进入播放页，开始朗读。';

  @override
  String get creatingHintCloud => '创作在云端继续；关掉本页也不影响。';

  @override
  String get creatingHintList => '返回「故事」列表可随时查看进度，或稍后再听。';

  @override
  String get creatingHintRetry => '点下方重试，会继续这篇故事，不额外占用额度。';

  @override
  String get creatingHintBackLater => '也可以先回列表，稍后再打开或重试。';

  @override
  String get creatingRetry => '重新生成';

  @override
  String get creatingRetrying => '重试中…';

  @override
  String get creatingBackFailed => '返回故事列表';

  @override
  String get creatingBackOk => '先回故事列表';

  @override
  String get voicesManageTitle => '音色管理';

  @override
  String get voicesManageEyebrow => '呼呼 · Voice';

  @override
  String get voicesManageHeaderTitle => '我的音色';

  @override
  String get voicesManageSubtitleClone => '管理朗读音色，或克隆家长声音给孩子讲故事';

  @override
  String get voicesManageSubtitleSystem => '管理系统朗读音色，试听并选用';

  @override
  String get voicesManageCloneCta => '克隆新音色';

  @override
  String get voicesManageSectionTitle => '已有音色';

  @override
  String get voicesManageNone => '暂无音色';

  @override
  String voicesManageCount(int count) {
    return '共 $count 个 · 可试听';
  }

  @override
  String get voicesManageEmptyCloneHint => '可先点上方按钮克隆家长声音。';

  @override
  String get voicesManageEmptySystemHint => '暂无可用系统音色，请稍后再试或联系管理员。';

  @override
  String get voicesKindClone => '克隆音色';

  @override
  String get voicesKindSystem => '系统音色';

  @override
  String get voicesPreviewUnavailable => '暂无试听';

  @override
  String get voicesPreviewUnavailableSnack => '该音色暂无试听，请稍后再试';

  @override
  String get voicesPreviewUnavailableShort => '该音色暂无试听';

  @override
  String get voicesPreviewFailed => '试听播放失败';

  @override
  String get voicesPreviewPlay => '试听';

  @override
  String get voicesPreviewStop => '停止试听';

  @override
  String get voicesPreviewStopShort => '停止';

  @override
  String get voicesNoPreviewSuffix => ' · 暂无试听';

  @override
  String get voiceCloneTitle => '克隆新音色';

  @override
  String get voiceCloneEyebrow => '呼呼 · Clone';

  @override
  String get voiceCloneHeaderTitle => '录制家长声音';

  @override
  String get voiceCloneHeaderSubtitle => '安静环境朗读约 10–15 秒，克隆后可用于睡前故事朗读';

  @override
  String get voiceCloneNameSection => '音色名称';

  @override
  String get voiceCloneNameHint => '例如：妈妈的声音、爸爸哄睡';

  @override
  String get voiceCloneDefaultName => '家长声音';

  @override
  String get voiceCloneUsageTitle => '使用说明';

  @override
  String get voiceCloneUsageBody => '原始录音上传后会尽快删除。克隆成功后可在创作故事时选用该音色。';

  @override
  String get voiceCloneConsent => '我同意将我的声音用于本 App 的睡前故事朗读';

  @override
  String get voiceCloneScriptTitle => '请朗读这段话';

  @override
  String get voiceCloneScriptSubtitle => '中英文各读一遍亦可，语速自然即可';

  @override
  String get voiceCloneScriptZh => '今晚我用温柔的声音给孩子讲故事。风很轻，月亮很亮，我们慢慢闭上眼睛。';

  @override
  String get voiceCloneStartRecord => '开始录音';

  @override
  String get voiceCloneStopRecord => '停止录音';

  @override
  String get voiceCloneRerecord => '重录一段';

  @override
  String get voiceCloneRecordingHint => '正在录音… 读完后点停止';

  @override
  String get voiceCloneReadyHint => '已录好样本，确认名称与同意后即可上传克隆';

  @override
  String get voiceCloneUpload => '上传并克隆';

  @override
  String get voiceCloneUploading => '上传中…';

  @override
  String get voiceCloneNeedMic => '需要麦克风权限';

  @override
  String get voiceCloneNeedName => '请先填写音色名称';

  @override
  String get voiceCloneNeedConsent => '请先勾选同意条款';

  @override
  String get voiceCloneSuccess => '克隆成功，可在生成故事时选用';

  @override
  String get voicePickerTitle => '选择音色';

  @override
  String get voicePickerHint => '试听后点确定使用';

  @override
  String get voicePickerUse => '使用此音色';

  @override
  String get voicePickerEmpty => '暂无';

  @override
  String get voicePickerUnnamed => '未命名音色';

  @override
  String get childrenManageTitle => '角色管理';

  @override
  String get childrenManageTagline => '梦境主角簿 · 定制专属睡前入眠物语';

  @override
  String get childrenTabListeners => '小听众档案';

  @override
  String get childrenTabPeople => '家人朋友';

  @override
  String get childrenTabToys => '玩具伙伴';

  @override
  String get childrenFabListener => '添加小听众';

  @override
  String get childrenFabPeople => '添加家人朋友';

  @override
  String get childrenFabToy => '添加玩具伙伴';

  @override
  String get childrenEmptyListenersTitle => '还没有小听众';

  @override
  String get childrenEmptyListenersBody => '添加小听众档案后，才能创建故事并挂上家人、玩具。';

  @override
  String get childrenEmptyListenersCta => '添加第一个小听众';

  @override
  String get childrenEmptyPeopleTitle => '还没有家人 / 朋友';

  @override
  String get childrenEmptyPeopleBody => '把外公、同学等建档后，创作故事时可勾选出场。';

  @override
  String get childrenEmptyToysTitle => '还没有玩具伙伴';

  @override
  String get childrenEmptyToysBody => '把娃娃、玩偶建档后，创作故事时可勾选出场。';

  @override
  String get childrenNeedListenerFirst => '请先添加小听众';

  @override
  String get childrenSheetTitle => '小听众档案';

  @override
  String get childrenNickname => '昵称';

  @override
  String get childrenGender => '性别';

  @override
  String get childrenBirthday => '生日';

  @override
  String get childrenPickBirthday => '选择生日';

  @override
  String get childrenBirthdayHint => '年/月/日';

  @override
  String get childrenIntroOptional => '简介（可选）';

  @override
  String get childrenIntroHint => '性格、近期心情…';

  @override
  String get childrenPreferLabel => '故事偏好（逗号分隔）';

  @override
  String get childrenPreferHint => '恐龙冒险, 温柔童话, 一点点幽默';

  @override
  String get childrenAddToy => '添加玩具';

  @override
  String get childrenEditToy => '编辑玩具';

  @override
  String get childrenAddPerson => '添加家人 / 朋友';

  @override
  String get childrenEditPerson => '编辑家人 / 朋友';

  @override
  String get childrenToyName => '名字';

  @override
  String get childrenPersonName => '称呼';

  @override
  String get childrenToyNameHint => '星星娃娃';

  @override
  String get childrenPersonNameHint => '外公';

  @override
  String get childrenBelongsTo => '属于谁';

  @override
  String get childrenLinkedListener => '关联小听众';

  @override
  String get childrenRelation => '关系';

  @override
  String get childrenRelationHint => '外公 / 同学 / 老师…';

  @override
  String get childrenToyNote => '外观 / 脾气（可选）';

  @override
  String get childrenPersonNote => '特征（可选）';

  @override
  String get childrenToyNoteHint => '蓝色耳朵、会唱歌';

  @override
  String get childrenPersonNoteHint => '爱讲故事';

  @override
  String get childrenDeleteListenerTitle => '删除小听众？';

  @override
  String childrenDeleteListenerBody(String name) {
    return '将一并删除「$name」名下的家人与玩具角色。';
  }

  @override
  String childrenDeleted(String name) {
    return '已删除「$name」';
  }

  @override
  String get childrenDeleteCharacterTitle => '删除角色？';

  @override
  String childrenDeleteCharacterBody(String name) {
    return '删除「$name」后，创作时将无法再勾选。';
  }

  @override
  String get childrenDefaultCharacter => '角色';

  @override
  String get childrenTagListener => '小听众';

  @override
  String get childrenTagToy => '安抚布偶';

  @override
  String get childrenTagPeople => '家人朋友';

  @override
  String childrenPreferPrefix(String prefs) {
    return '偏好：$prefs';
  }

  @override
  String get childrenEditPrefs => '编辑档案与睡前偏好';

  @override
  String get childrenSleepPreset => '入眠预设';

  @override
  String childrenBelongsToName(String name) {
    return '属于 $name';
  }

  @override
  String childrenToySubtitle(String name) {
    return '床头伙伴 · 属于 $name';
  }

  @override
  String childrenPersonalityPrefix(String note) {
    return '性格：$note';
  }

  @override
  String get childrenUnlinked => '未关联';

  @override
  String childrenChildFallback(int id) {
    return '小孩 #$id';
  }

  @override
  String get childrenMagicTitle => '角色定制魔力';

  @override
  String get childrenMagicBody => '织梦引擎根据主角年龄与偏好，在每晚的声景中植入专属温润台词与助眠呼吸节律。';

  @override
  String get createStoryTitle => '定制今晚的故事';

  @override
  String get createStoryNeedListenerTitle => '先添加小听众';

  @override
  String get createStoryNeedListenerSubtitle => '有了孩子档案，才能定制今晚的故事';

  @override
  String get createStoryNoRolesTitle => '还没有角色';

  @override
  String get createStoryNoRolesBody => '请先创建孩子档案（昵称、年龄等）。创建后即可回来生成故事。';

  @override
  String get createStoryGoAddChild => '去添加孩子档案';

  @override
  String get createStoryGenerate => '生成今晚的故事';

  @override
  String get createStoryGenerating => '生成中…';

  @override
  String get createStoryQuotaPrefix => '本月故事 ';

  @override
  String createStoryQuotaLine(Object used, Object limit) {
    return '本月故事 $used/$limit';
  }

  @override
  String get createStoryListenersTitle => '今晚，讲给谁听？';

  @override
  String get createStoryListenersSubMulti => '可多选；故事会以小听众的偏好来编织';

  @override
  String get createStoryListenersSubSingle => '故事会以小听众偏好来编织';

  @override
  String get createStoryManageListeners => '管理小听众档案';

  @override
  String get createStoryPrimaryListener => '主听众';

  @override
  String get createStoryNoPrefer => '暂无故事偏好 · 偏爱睡前童话';

  @override
  String get createStoryOptionsTitle => '想听什么故事？';

  @override
  String get createStoryOptionsSubtitle => '故事将依据这些要素来创作';

  @override
  String get createStoryInspiration => '故事灵感';

  @override
  String get createStoryInspirationHint => '可选，不写也可以';

  @override
  String get createStoryThemeHint => '今晚想讲什么（可选，例如：在云朵上看星星的小猫咪…）';

  @override
  String get createStoryCastTitle => '今晚一起出场';

  @override
  String get createStoryAddCharacter => '添加角色';

  @override
  String get createStoryCastEmpty => '可在角色管理中添加小听众、家人或玩具。';

  @override
  String get createStoryCharacterFallback => '角色';

  @override
  String get createStoryType => '故事类型';

  @override
  String get createStoryVoice => '朗读音色';

  @override
  String createStoryVoiceSelected(String name) {
    return '已选：$name';
  }

  @override
  String get createStoryVoiceNone => '未选音色';

  @override
  String get createStoryVoicePick => '请选音色';

  @override
  String get createStoryVoiceChange => '更换';

  @override
  String get createStoryMoreOptions => '更多选项（语言与对话）';

  @override
  String get createStoryLanguage => '讲述语言';

  @override
  String get createStoryLangZh => '中文';

  @override
  String get createStoryEnglishSoon => '英文故事暂未开放，敬请期待';

  @override
  String get createStoryDialogue => '对话多少';

  @override
  String get createStoryTypeEveryday => '日常生活';

  @override
  String get createStoryTypeSoft => '一点想象';

  @override
  String get createStoryTypeFantasy => '奇妙世界';

  @override
  String get createStoryDialogueLow => '很少对话';

  @override
  String get createStoryDialogueSome => '一点对话';

  @override
  String get createStoryDialogueMore => '对话多些';

  @override
  String get createStorySoftSeries => '软系列（可续写）';

  @override
  String get createStorySoftHook => '上一集轻钩子（可选）';

  @override
  String get createStoryEpisodeNo => '系列集数';

  @override
  String get createStoryDreamRules => '织梦守则';

  @override
  String get createStoryDreamRulesBody => '故事将自动调节平静舒缓的语言节奏，末尾缓缓淡入晚安白噪音。';

  @override
  String get createStoryDuration => '时长 (分钟)';

  @override
  String get createStoryErrAddChild => '请先添加孩子档案';

  @override
  String get createStoryErrNickname => '请先完善孩子昵称（点档案卡片编辑）';

  @override
  String get createStoryErrVoice => '请选择音色（或先到「音色」页创建系统音色）';

  @override
  String get createStoryErrListener => '请先选择今晚的小听众';

  @override
  String get playerTitle => '伴读';

  @override
  String get playerStatusLive => '床头暖灯 · 伴睡夜播中';

  @override
  String get playerModePicture => '绘本伴读';

  @override
  String get playerModeAudio => '纯听';

  @override
  String get playerWarmLight => '枕边暖光';

  @override
  String get playerBrandLine => '呼呼 · 枕边故事';

  @override
  String get playerCoRead => '亲子同屏伴读';

  @override
  String get playerFullText => '全文';

  @override
  String get playerFollowAlong => '字句平滑随行';

  @override
  String get playerCollapse => '收起';

  @override
  String get playerExpand => '查看全文';

  @override
  String get playerSpeedTitle => '朗读倍速';

  @override
  String get playerSpeedHint => '只改变故事朗读速度，背景音乐不受影响。不会重新合成音频。';

  @override
  String playerSpeedCurrent(String speed) {
    return '当前 $speed×';
  }

  @override
  String playerBedTrack(String label) {
    return '摇篮背景音 · $label';
  }

  @override
  String get playerBedMusicBox => '八音盒';

  @override
  String playerRemain(String time) {
    return '剩余 $time';
  }

  @override
  String get playerBedFading => '背景音正慢慢停下';

  @override
  String get playerOutroOff => '结束后即关助眠音乐';

  @override
  String playerOutroMinutes(int minutes) {
    return '结束后再播$minutes分钟';
  }

  @override
  String get playerOutroOffShort => '即关';

  @override
  String playerOutroMinutesShort(int minutes) {
    return '$minutes分钟';
  }

  @override
  String get playerBedOff => '已关';

  @override
  String get playerScript => '文稿';

  @override
  String get playerTimerTitle => '定时关闭音乐';

  @override
  String get playerTimerSubtitle => '故事结束后延迟关闭助眠音乐';

  @override
  String playerTimerFading(String time) {
    return '助眠音乐正慢慢停下 · 剩余 $time';
  }

  @override
  String get playerTimerDelay => '延迟时长';

  @override
  String get createStoryDurationMood3 => '3 分钟 · 短篇微睡';

  @override
  String get createStoryDurationMood5 => '5 分钟 · 适合入睡';

  @override
  String get createStoryDurationMood8 => '8 分钟 · 沉浸暖梦';

  @override
  String get createStoryDurationMood10 => '10 分钟 · 悠长童话';

  @override
  String get createStoryDurationMood12 => '12 分钟 · 深度安歇';

  @override
  String createStoryDurationMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get playerOutroMood0 => '0 分钟 · 故事结束即关';

  @override
  String get playerOutroMood1 => '1 分钟 · 余韵轻停';

  @override
  String get playerOutroMood5 => '5 分钟 · 温柔收束';

  @override
  String get playerOutroMood10 => '10 分钟 · 慢慢入静';

  @override
  String get playerOutroMood15 => '15 分钟 · 安睡余音';

  @override
  String get playerOutroMood30 => '30 分钟 · 整夜轻伴';

  @override
  String playerOutroMoodMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String ageYears(int years) {
    return '$years岁';
  }

  @override
  String ageYearsMonths(int years, int months) {
    return '$years岁 $months个月';
  }

  @override
  String get commonPleaseSelect => '请选择';

  @override
  String get storiesContinueEpisodeTooltip => '续写下一集';

  @override
  String get netTimeout => '网络超时，请稍后再试';

  @override
  String get netOfflineCached => '网络不可用，已显示本地缓存';

  @override
  String get apiSessionExpired => '登录已失效，请重新进入';

  @override
  String get apiRefreshFailed => '刷新登录失败';

  @override
  String get apiStoryGenerateFailed => '故事生成失败';

  @override
  String get apiStoryCreateFailed => '故事创建失败';

  @override
  String get apiStoryWaitNetworkUnstable => '网络不稳定，生成可能仍在进行。可稍后在「故事」刷新，或点继续等待';

  @override
  String get apiStoryWaitTimeout => '网络超时，生成可能仍在进行。可稍后刷新或点继续等待';

  @override
  String get apiStoryWaitOffline => '网络不可用，生成可能仍在进行。恢复网络后可点继续等待';

  @override
  String get apiStoryWaitDeadline => '等待故事生成超时，可在「故事」里查看是否已完成';

  @override
  String get apiNetworkUnstableRetry => '网络不稳定，请稍后重试';

  @override
  String get apiForbidden => '没有权限执行该操作';

  @override
  String get apiNotFound => '未找到相关内容';

  @override
  String get apiTooManyRequests => '请求过于频繁，请稍后再试';

  @override
  String get apiServerUnavailable => '服务暂时不可用，请稍后再试';

  @override
  String apiRequestFailed(int statusCode) {
    return '请求失败 ($statusCode)';
  }

  @override
  String get bootCannotConnect => '无法连接';

  @override
  String get bootRetry => '重试';

  @override
  String get bootHintRemote =>
      '线上/内测请用：flutter run --dart-define=APP_ENV=staging\n（见 assets/config/staging.json），并用邀请码注册或手机号登录。';

  @override
  String get bootHintLocal =>
      '若卡在白屏或连不上：系统设置 → 隐私与安全性 → 本地网络 → 打开本 App；\n真机请在 assets/config/dev.local.json（从 *.example 复制）把 api_base_url 设为 http://<电脑局域网IP>:8000。';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => '呼呼 · 枕邊故事';

  @override
  String get meTitle => '我的';

  @override
  String get tabStories => '故事';

  @override
  String get meSettings => '設定';

  @override
  String get meVoicesTitle => '音色管理';

  @override
  String get meVoicesSubtitleClone => '系統音色與家長聲音克隆';

  @override
  String get meVoicesSubtitle => '系統朗讀音色';

  @override
  String get meCharactersTitle => '角色管理';

  @override
  String get meCharactersSubtitle => '小聽眾檔案與故事角色';

  @override
  String get meLanguageTitle => '語言';

  @override
  String meLanguageSubtitle(String label) {
    return '$label';
  }

  @override
  String get meAboutTitle => '關於';

  @override
  String get meAboutSubtitle => '產品與聯絡方式';

  @override
  String get meTermsTitle => '使用者協議';

  @override
  String get meTermsSubtitle => '使用條款';

  @override
  String get mePrivacyTitle => '隱私政策';

  @override
  String get mePrivacySubtitle => '我們如何處理你的資料';

  @override
  String meVersion(String version) {
    return 'Version $version';
  }

  @override
  String get meLogoutAccount => '退出目前帳號';

  @override
  String meBrandFooter(String version) {
    return '呼呼 · 枕邊故事  版本v$version';
  }

  @override
  String get languagePickerTitle => '語言';

  @override
  String get languageZhHans => '简体中文';

  @override
  String get languageZhHant => '繁體中文';

  @override
  String get languageEn => 'English';

  @override
  String get profileGuest => '未登入';

  @override
  String get profileGuestHint => '登入後可同步故事與音色';

  @override
  String get profileConnected => '已連接枕邊故事服務';

  @override
  String get profileDefaultName => '枕邊家長';

  @override
  String get profileLogin => '登入';

  @override
  String get profileLogout => '登出';

  @override
  String get profileRefresh => '重新整理';

  @override
  String quotaStories(Object used, Object limit) {
    return '本月故事 $used/$limit';
  }

  @override
  String quotaCloneSuffix(Object used, Object limit) {
    return ' · 克隆 $used/$limit';
  }

  @override
  String get aboutTitle => '關於';

  @override
  String get aboutTagline => '為孩子編織溫柔的枕邊故事';

  @override
  String get aboutVersionLabel => '版本';

  @override
  String get aboutDeveloperLabel => '開發者';

  @override
  String get aboutDeveloperName => '風息谷工作室';

  @override
  String get aboutSupportLabel => '支援';

  @override
  String get aboutWebsiteLabel => '網站';

  @override
  String get aboutTermsLink => '使用者協議';

  @override
  String get aboutPrivacyLink => '隱私政策';

  @override
  String aboutCopyright(int year) {
    return '© $year Lullvale';
  }

  @override
  String get termsTitle => '使用者協議';

  @override
  String get privacyTitle => '隱私政策';

  @override
  String get legalOpenFailed => '無法開啟連結。';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '確定';

  @override
  String get commonDelete => '刪除';

  @override
  String get commonEdit => '編輯';

  @override
  String get commonCreate => '建立';

  @override
  String get commonSave => '儲存';

  @override
  String get commonClose => '關閉';

  @override
  String get commonUnnamed => '未命名';

  @override
  String get commonLoading => '載入中';

  @override
  String get genderUnspecified => '不指定';

  @override
  String get genderBoy => '男孩';

  @override
  String get genderGirl => '女孩';

  @override
  String get genderOther => '其他';

  @override
  String get homeOfflineSnackbar => '離線模式：顯示本機快取，連線後自動同步';

  @override
  String get authBrandName => '呼呼';

  @override
  String get authBrandBadge => '枕邊故事';

  @override
  String get authSubtitleLogin => '登入後繼續枕邊故事';

  @override
  String get authSubtitleRegister => '使用邀請碼建立帳號';

  @override
  String get authInviteCode => '邀請碼';

  @override
  String get authNicknameOptional => '暱稱（可選）';

  @override
  String get authPhone => '手機號碼';

  @override
  String get authPassword => '密碼';

  @override
  String get authConfirmPassword => '確認密碼';

  @override
  String get authShowPassword => '顯示密碼';

  @override
  String get authHidePassword => '隱藏密碼';

  @override
  String get authLoginSms => '驗證碼登入';

  @override
  String get authForgotPassword => '忘記密碼？';

  @override
  String get authSubmitLogin => '登入';

  @override
  String get authSubmitRegister => '註冊並登入';

  @override
  String get authHaveAccount => '已有帳號？ ';

  @override
  String get authHaveInvite => '有邀請碼？ ';

  @override
  String get authGoLogin => '去登入';

  @override
  String get authGoRegister => '去註冊';

  @override
  String get authNightHint => '夜間低藍光護眼設計 · 願你今晚有好夢';

  @override
  String get authAgreeRegisterPrefix => '註冊即代表同意 ';

  @override
  String get authAgreeLoginPrefix => '登入即代表您已同意 ';

  @override
  String get authTermsLink => '使用者協議';

  @override
  String get authAnd => ' 與 ';

  @override
  String get authPrivacyLink => '隱私政策';

  @override
  String get authPrivacyLinkRegister => '隱私保護政策';

  @override
  String get authErrorInviteRequired => '請填寫邀請碼';

  @override
  String get authErrorPhoneRequired => '請填寫手機號碼';

  @override
  String get authErrorPasswordShort => '密碼至少 8 位';

  @override
  String get authErrorPasswordMismatch => '兩次輸入的密碼不一致';

  @override
  String get authErrorPasswordRequired => '請填寫密碼';

  @override
  String get authErrorInvalidResponse => '登入回應無效';

  @override
  String authComingSoon(String feature) {
    return '$feature暫未開放，敬請期待';
  }

  @override
  String get authFeatureSmsLogin => '驗證碼登入';

  @override
  String get authFeatureRecoverPassword => '找回密碼';

  @override
  String get authClose => '關閉';

  @override
  String get storyProgressQueued => '排隊中…';

  @override
  String get storyProgressSeriesOutline => '正在構思系列大綱…';

  @override
  String get storyProgressEpisodePlan => '正在構思今晚情節…';

  @override
  String get storyProgressDraft => '正在寫故事正文…';

  @override
  String get storyProgressTts => '正在產生朗讀音訊…';

  @override
  String get storyProgressReady => '完成';

  @override
  String get storyProgressReadyPlay => '完成，準備播放…';

  @override
  String get storyProgressFailed => '產生失敗';

  @override
  String storyProgressGenerating(String progress) {
    return '產生中（$progress）…';
  }

  @override
  String get storyGenerateFailed => '故事產生失敗';

  @override
  String get storyGenerateFailedRetry => '故事產生失敗，可點重試';

  @override
  String get storyStillGenerating => '故事還在產生中，請下拉重新整理後再聽';

  @override
  String get storyNoAudio => '暫無音訊，無法播放';

  @override
  String get storyNoAudioShort => '暫無音訊';

  @override
  String get storyCreateFailed => '故事建立失敗';

  @override
  String get storyRetrying => '正在重新產生…';

  @override
  String get storyResumeWaiting => '繼續等待產生…';

  @override
  String get storyContinueWaiting => '繼續等待';

  @override
  String get storyContinuingEpisode => '正在續寫下一集…';

  @override
  String get storySubmittedQueued => '已提交，排隊中…';

  @override
  String get storiesTitle => '故事';

  @override
  String get storiesStatusWaitingFirst => '等待第一篇';

  @override
  String get storiesStatusReady => '夜光模式已就緒';

  @override
  String get storiesCreateEyebrow => '織夢引擎 · 新章';

  @override
  String get storiesCreateTitle => '創作今晚的故事';

  @override
  String get storiesCreateSubtitle => '訂製專屬角色、故事情節與助眠音畫';

  @override
  String get storiesLibraryTitle => '枕邊故事寶盒';

  @override
  String get storiesLibraryEmpty => '暫無故事';

  @override
  String storiesLibraryCount(int count) {
    return '按時間倒序 · $count 篇';
  }

  @override
  String get storiesEmptyShelfTitle => '空空的書架';

  @override
  String get storiesEmptyShelfBody => '今晚的第一本小書，還在等你點上方金色卡片。';

  @override
  String get storiesUntitled => '未完成的故事';

  @override
  String get storiesFailedRetry => '產生失敗 · 可重試';

  @override
  String storiesFailedWithError(String error) {
    return '失敗 · $error';
  }

  @override
  String get storiesSeriesContinueHint => '系列續寫請從「創作」頁重新開始';

  @override
  String storiesMinutes(Object minutes) {
    return '$minutes 分鐘';
  }

  @override
  String storiesSeriesMeta(Object id) {
    return '系列 #$id';
  }

  @override
  String storiesEpisodeMeta(Object ep) {
    return ' 第$ep集';
  }

  @override
  String get creatingTitle => '創作中';

  @override
  String get creatingBackTooltip => '返回故事列表';

  @override
  String get creatingHeadlineOk => '正在為今晚寫故事';

  @override
  String get creatingHeadlineFail => '這次沒能完成';

  @override
  String get creatingBodyOk => '雲端正在寫正文並錄製朗讀，通常需要一兩分鐘。';

  @override
  String get creatingBodyFail => '可以重試，或先回列表，稍後再打開這篇故事。';

  @override
  String get creatingHintsOkTitle => '產生時你可以';

  @override
  String get creatingHintsFailTitle => '接下來可以';

  @override
  String get creatingHintAutoPlay => '完成後會自動進入播放頁，開始朗讀。';

  @override
  String get creatingHintCloud => '創作在雲端繼續；關掉本頁也不影響。';

  @override
  String get creatingHintList => '返回「故事」列表可隨時查看進度，或稍後再聽。';

  @override
  String get creatingHintRetry => '點下方重試，會繼續這篇故事，不額外佔用額度。';

  @override
  String get creatingHintBackLater => '也可以先回列表，稍後再打開或重試。';

  @override
  String get creatingRetry => '重新產生';

  @override
  String get creatingRetrying => '重試中…';

  @override
  String get creatingBackFailed => '返回故事列表';

  @override
  String get creatingBackOk => '先回故事列表';

  @override
  String get voicesManageTitle => '音色管理';

  @override
  String get voicesManageEyebrow => '呼呼 · Voice';

  @override
  String get voicesManageHeaderTitle => '我的音色';

  @override
  String get voicesManageSubtitleClone => '管理朗讀音色，或克隆家長聲音給孩子講故事';

  @override
  String get voicesManageSubtitleSystem => '管理系統朗讀音色，試聽並選用';

  @override
  String get voicesManageCloneCta => '克隆新音色';

  @override
  String get voicesManageSectionTitle => '已有音色';

  @override
  String get voicesManageNone => '暫無音色';

  @override
  String voicesManageCount(int count) {
    return '共 $count 個 · 可試聽';
  }

  @override
  String get voicesManageEmptyCloneHint => '可先點上方按鈕克隆家長聲音。';

  @override
  String get voicesManageEmptySystemHint => '暫無可用系統音色，請稍後再試或聯絡管理員。';

  @override
  String get voicesKindClone => '克隆音色';

  @override
  String get voicesKindSystem => '系統音色';

  @override
  String get voicesPreviewUnavailable => '暫無試聽';

  @override
  String get voicesPreviewUnavailableSnack => '該音色暫無試聽，請稍後再試';

  @override
  String get voicesPreviewUnavailableShort => '該音色暫無試聽';

  @override
  String get voicesPreviewFailed => '試聽播放失敗';

  @override
  String get voicesPreviewPlay => '試聽';

  @override
  String get voicesPreviewStop => '停止試聽';

  @override
  String get voicesPreviewStopShort => '停止';

  @override
  String get voicesNoPreviewSuffix => ' · 暫無試聽';

  @override
  String get voiceCloneTitle => '克隆新音色';

  @override
  String get voiceCloneEyebrow => '呼呼 · Clone';

  @override
  String get voiceCloneHeaderTitle => '錄製家長聲音';

  @override
  String get voiceCloneHeaderSubtitle => '安靜環境朗讀約 10–15 秒，克隆後可用於睡前故事朗讀';

  @override
  String get voiceCloneNameSection => '音色名稱';

  @override
  String get voiceCloneNameHint => '例如：媽媽的聲音、爸爸哄睡';

  @override
  String get voiceCloneDefaultName => '家長聲音';

  @override
  String get voiceCloneUsageTitle => '使用說明';

  @override
  String get voiceCloneUsageBody => '原始錄音上傳後會盡快刪除。克隆成功後可在創作故事時選用該音色。';

  @override
  String get voiceCloneConsent => '我同意將我的聲音用於本 App 的睡前故事朗讀';

  @override
  String get voiceCloneScriptTitle => '請朗讀這段話';

  @override
  String get voiceCloneScriptSubtitle => '中英文各讀一遍亦可，語速自然即可';

  @override
  String get voiceCloneScriptZh => '今晚我用溫柔的聲音給孩子講故事。風很輕，月亮很亮，我們慢慢閉上眼睛。';

  @override
  String get voiceCloneStartRecord => '開始錄音';

  @override
  String get voiceCloneStopRecord => '停止錄音';

  @override
  String get voiceCloneRerecord => '重錄一段';

  @override
  String get voiceCloneRecordingHint => '正在錄音… 讀完後點停止';

  @override
  String get voiceCloneReadyHint => '已錄好樣本，確認名稱與同意後即可上傳克隆';

  @override
  String get voiceCloneUpload => '上傳並克隆';

  @override
  String get voiceCloneUploading => '上傳中…';

  @override
  String get voiceCloneNeedMic => '需要麥克風權限';

  @override
  String get voiceCloneNeedName => '請先填寫音色名稱';

  @override
  String get voiceCloneNeedConsent => '請先勾選同意條款';

  @override
  String get voiceCloneSuccess => '克隆成功，可在產生故事時選用';

  @override
  String get voicePickerTitle => '選擇音色';

  @override
  String get voicePickerHint => '試聽後點確定使用';

  @override
  String get voicePickerUse => '使用此音色';

  @override
  String get voicePickerEmpty => '暫無';

  @override
  String get voicePickerUnnamed => '未命名音色';

  @override
  String get childrenManageTitle => '角色管理';

  @override
  String get childrenManageTagline => '夢境主角簿 · 訂製專屬睡前入眠物語';

  @override
  String get childrenTabListeners => '小聽眾檔案';

  @override
  String get childrenTabPeople => '家人朋友';

  @override
  String get childrenTabToys => '玩具伙伴';

  @override
  String get childrenFabListener => '新增小聽眾';

  @override
  String get childrenFabPeople => '新增家人朋友';

  @override
  String get childrenFabToy => '新增玩具伙伴';

  @override
  String get childrenEmptyListenersTitle => '還沒有小聽眾';

  @override
  String get childrenEmptyListenersBody => '新增小聽眾檔案後，才能建立故事並掛上家人、玩具。';

  @override
  String get childrenEmptyListenersCta => '新增第一個小聽眾';

  @override
  String get childrenEmptyPeopleTitle => '還沒有家人 / 朋友';

  @override
  String get childrenEmptyPeopleBody => '把外公、同學等建檔後，創作故事時可勾選出場。';

  @override
  String get childrenEmptyToysTitle => '還沒有玩具伙伴';

  @override
  String get childrenEmptyToysBody => '把娃娃、玩偶建檔後，創作故事時可勾選出場。';

  @override
  String get childrenNeedListenerFirst => '請先新增小聽眾';

  @override
  String get childrenSheetTitle => '小聽眾檔案';

  @override
  String get childrenNickname => '暱稱';

  @override
  String get childrenGender => '性別';

  @override
  String get childrenBirthday => '生日';

  @override
  String get childrenPickBirthday => '選擇生日';

  @override
  String get childrenBirthdayHint => '年/月/日';

  @override
  String get childrenIntroOptional => '簡介（可選）';

  @override
  String get childrenIntroHint => '性格、近期心情…';

  @override
  String get childrenPreferLabel => '故事偏好（逗號分隔）';

  @override
  String get childrenPreferHint => '恐龍冒險, 溫柔童話, 一點點幽默';

  @override
  String get childrenAddToy => '新增玩具';

  @override
  String get childrenEditToy => '編輯玩具';

  @override
  String get childrenAddPerson => '新增家人 / 朋友';

  @override
  String get childrenEditPerson => '編輯家人 / 朋友';

  @override
  String get childrenToyName => '名字';

  @override
  String get childrenPersonName => '稱呼';

  @override
  String get childrenToyNameHint => '星星娃娃';

  @override
  String get childrenPersonNameHint => '外公';

  @override
  String get childrenBelongsTo => '屬於誰';

  @override
  String get childrenLinkedListener => '關聯小聽眾';

  @override
  String get childrenRelation => '關係';

  @override
  String get childrenRelationHint => '外公 / 同學 / 老師…';

  @override
  String get childrenToyNote => '外觀 / 脾氣（可選）';

  @override
  String get childrenPersonNote => '特徵（可選）';

  @override
  String get childrenToyNoteHint => '藍色耳朵、會唱歌';

  @override
  String get childrenPersonNoteHint => '愛講故事';

  @override
  String get childrenDeleteListenerTitle => '刪除小聽眾？';

  @override
  String childrenDeleteListenerBody(String name) {
    return '將一併刪除「$name」名下的家人與玩具角色。';
  }

  @override
  String childrenDeleted(String name) {
    return '已刪除「$name」';
  }

  @override
  String get childrenDeleteCharacterTitle => '刪除角色？';

  @override
  String childrenDeleteCharacterBody(String name) {
    return '刪除「$name」後，創作時將無法再勾選。';
  }

  @override
  String get childrenDefaultCharacter => '角色';

  @override
  String get childrenTagListener => '小聽眾';

  @override
  String get childrenTagToy => '安撫布偶';

  @override
  String get childrenTagPeople => '家人朋友';

  @override
  String childrenPreferPrefix(String prefs) {
    return '偏好：$prefs';
  }

  @override
  String get childrenEditPrefs => '編輯檔案與睡前偏好';

  @override
  String get childrenSleepPreset => '入眠預設';

  @override
  String childrenBelongsToName(String name) {
    return '屬於 $name';
  }

  @override
  String childrenToySubtitle(String name) {
    return '床頭伙伴 · 屬於 $name';
  }

  @override
  String childrenPersonalityPrefix(String note) {
    return '性格：$note';
  }

  @override
  String get childrenUnlinked => '未關聯';

  @override
  String childrenChildFallback(int id) {
    return '小孩 #$id';
  }

  @override
  String get childrenMagicTitle => '角色訂製魔力';

  @override
  String get childrenMagicBody => '織夢引擎根據主角年齡與偏好，在每晚的聲景中植入專屬溫潤台詞與助眠呼吸節律。';

  @override
  String get createStoryTitle => '訂製今晚的故事';

  @override
  String get createStoryNeedListenerTitle => '先新增小聽眾';

  @override
  String get createStoryNeedListenerSubtitle => '有了孩子檔案，才能訂製今晚的故事';

  @override
  String get createStoryNoRolesTitle => '還沒有角色';

  @override
  String get createStoryNoRolesBody => '請先建立孩子檔案（暱稱、年齡等）。建立後即可回來產生故事。';

  @override
  String get createStoryGoAddChild => '去新增孩子檔案';

  @override
  String get createStoryGenerate => '產生今晚的故事';

  @override
  String get createStoryGenerating => '產生中…';

  @override
  String get createStoryQuotaPrefix => '本月故事 ';

  @override
  String createStoryQuotaLine(Object used, Object limit) {
    return '本月故事 $used/$limit';
  }

  @override
  String get createStoryListenersTitle => '今晚，講給誰聽？';

  @override
  String get createStoryListenersSubMulti => '可多選；故事會以小聽眾的偏好來編織';

  @override
  String get createStoryListenersSubSingle => '故事會以小聽眾偏好來編織';

  @override
  String get createStoryManageListeners => '管理小聽眾檔案';

  @override
  String get createStoryPrimaryListener => '主聽眾';

  @override
  String get createStoryNoPrefer => '暫無故事偏好 · 偏愛睡前童話';

  @override
  String get createStoryOptionsTitle => '想聽什麼故事？';

  @override
  String get createStoryOptionsSubtitle => '故事將依據這些要素來創作';

  @override
  String get createStoryInspiration => '故事靈感';

  @override
  String get createStoryInspirationHint => '可選，不寫也可以';

  @override
  String get createStoryThemeHint => '今晚想講什麼（可選，例如：在雲朵上看星星的小貓咪…）';

  @override
  String get createStoryCastTitle => '今晚一起出場';

  @override
  String get createStoryAddCharacter => '新增角色';

  @override
  String get createStoryCastEmpty => '可在角色管理中新增小聽眾、家人或玩具。';

  @override
  String get createStoryCharacterFallback => '角色';

  @override
  String get createStoryType => '故事類型';

  @override
  String get createStoryVoice => '朗讀音色';

  @override
  String createStoryVoiceSelected(String name) {
    return '已選：$name';
  }

  @override
  String get createStoryVoiceNone => '未選音色';

  @override
  String get createStoryVoicePick => '請選音色';

  @override
  String get createStoryVoiceChange => '更換';

  @override
  String get createStoryMoreOptions => '更多選項（語言與對話）';

  @override
  String get createStoryLanguage => '講述語言';

  @override
  String get createStoryLangZh => '中文';

  @override
  String get createStoryEnglishSoon => '英文故事暫未開放，敬請期待';

  @override
  String get createStoryDialogue => '對話多少';

  @override
  String get createStoryTypeEveryday => '日常生活';

  @override
  String get createStoryTypeSoft => '一點想像';

  @override
  String get createStoryTypeFantasy => '奇妙世界';

  @override
  String get createStoryDialogueLow => '很少對話';

  @override
  String get createStoryDialogueSome => '一點對話';

  @override
  String get createStoryDialogueMore => '對話多些';

  @override
  String get createStorySoftSeries => '軟系列（可續寫）';

  @override
  String get createStorySoftHook => '上一集輕鉤子（可選）';

  @override
  String get createStoryEpisodeNo => '系列集數';

  @override
  String get createStoryDreamRules => '織夢守則';

  @override
  String get createStoryDreamRulesBody => '故事將自動調節平靜舒緩的語言節奏，末尾緩緩淡入晚安白噪音。';

  @override
  String get createStoryDuration => '時長 (分鐘)';

  @override
  String get createStoryErrAddChild => '請先新增孩子檔案';

  @override
  String get createStoryErrNickname => '請先完善孩子暱稱（點檔案卡片編輯）';

  @override
  String get createStoryErrVoice => '請選擇音色（或先到「音色」頁建立系統音色）';

  @override
  String get createStoryErrListener => '請先選擇今晚的小聽眾';

  @override
  String get playerTitle => '伴讀';

  @override
  String get playerStatusLive => '床頭暖燈 · 伴睡夜播中';

  @override
  String get playerModePicture => '繪本伴讀';

  @override
  String get playerModeAudio => '純聽';

  @override
  String get playerWarmLight => '枕邊暖光';

  @override
  String get playerBrandLine => '呼呼 · 枕邊故事';

  @override
  String get playerCoRead => '親子同屏伴讀';

  @override
  String get playerFullText => '全文';

  @override
  String get playerFollowAlong => '字句平滑隨行';

  @override
  String get playerCollapse => '收起';

  @override
  String get playerExpand => '查看全文';

  @override
  String get playerSpeedTitle => '朗讀倍速';

  @override
  String get playerSpeedHint => '只改變故事朗讀速度，背景音樂不受影響。不會重新合成音訊。';

  @override
  String playerSpeedCurrent(String speed) {
    return '目前 $speed×';
  }

  @override
  String playerBedTrack(String label) {
    return '搖籃背景音 · $label';
  }

  @override
  String get playerBedMusicBox => '八音盒';

  @override
  String playerRemain(String time) {
    return '剩餘 $time';
  }

  @override
  String get playerBedFading => '背景音正慢慢停下';

  @override
  String get playerOutroOff => '結束後即關助眠音樂';

  @override
  String playerOutroMinutes(int minutes) {
    return '結束後再播$minutes分鐘';
  }

  @override
  String get playerOutroOffShort => '即關';

  @override
  String playerOutroMinutesShort(int minutes) {
    return '$minutes分鐘';
  }

  @override
  String get playerBedOff => '已關';

  @override
  String get playerScript => '文稿';

  @override
  String get playerTimerTitle => '定時關閉音樂';

  @override
  String get playerTimerSubtitle => '故事結束後延遲關閉助眠音樂';

  @override
  String playerTimerFading(String time) {
    return '助眠音樂正慢慢停下 · 剩餘 $time';
  }

  @override
  String get playerTimerDelay => '延遲時長';

  @override
  String get createStoryDurationMood3 => '3 分鐘 · 短篇微睡';

  @override
  String get createStoryDurationMood5 => '5 分鐘 · 適合入睡';

  @override
  String get createStoryDurationMood8 => '8 分鐘 · 沉浸暖夢';

  @override
  String get createStoryDurationMood10 => '10 分鐘 · 悠長童話';

  @override
  String get createStoryDurationMood12 => '12 分鐘 · 深度安歇';

  @override
  String createStoryDurationMinutes(int minutes) {
    return '$minutes 分鐘';
  }

  @override
  String get playerOutroMood0 => '0 分鐘 · 故事結束即關';

  @override
  String get playerOutroMood1 => '1 分鐘 · 餘韻輕停';

  @override
  String get playerOutroMood5 => '5 分鐘 · 溫柔收束';

  @override
  String get playerOutroMood10 => '10 分鐘 · 慢慢入靜';

  @override
  String get playerOutroMood15 => '15 分鐘 · 安睡餘音';

  @override
  String get playerOutroMood30 => '30 分鐘 · 整夜輕伴';

  @override
  String playerOutroMoodMinutes(int minutes) {
    return '$minutes 分鐘';
  }

  @override
  String ageYears(int years) {
    return '$years歲';
  }

  @override
  String ageYearsMonths(int years, int months) {
    return '$years歲 $months個月';
  }

  @override
  String get commonPleaseSelect => '請選擇';

  @override
  String get storiesContinueEpisodeTooltip => '續寫下一集';

  @override
  String get netTimeout => '網路逾時，請稍後再試';

  @override
  String get netOfflineCached => '網路不可用，已顯示本地快取';

  @override
  String get apiSessionExpired => '登入已失效，請重新進入';

  @override
  String get apiRefreshFailed => '重新整理登入失敗';

  @override
  String get apiStoryGenerateFailed => '故事生成失敗';

  @override
  String get apiStoryCreateFailed => '故事建立失敗';

  @override
  String get apiStoryWaitNetworkUnstable =>
      '網路不穩定，生成可能仍在進行。可稍後在「故事」重新整理，或點繼續等待';

  @override
  String get apiStoryWaitTimeout => '網路逾時，生成可能仍在進行。可稍後重新整理或點繼續等待';

  @override
  String get apiStoryWaitOffline => '網路不可用，生成可能仍在進行。恢復網路後可點繼續等待';

  @override
  String get apiStoryWaitDeadline => '等待故事生成逾時，可在「故事」裡查看是否已完成';

  @override
  String get apiNetworkUnstableRetry => '網路不穩定，請稍後再試';

  @override
  String get apiForbidden => '沒有權限執行該操作';

  @override
  String get apiNotFound => '找不到相關內容';

  @override
  String get apiTooManyRequests => '請求過於頻繁，請稍後再試';

  @override
  String get apiServerUnavailable => '服務暫時無法使用，請稍後再試';

  @override
  String apiRequestFailed(int statusCode) {
    return '請求失敗 ($statusCode)';
  }

  @override
  String get bootCannotConnect => '無法連線';

  @override
  String get bootRetry => '重試';

  @override
  String get bootHintRemote =>
      '線上/內測請用：flutter run --dart-define=APP_ENV=staging\n（見 assets/config/staging.json），並用邀請碼註冊或手機號登入。';

  @override
  String get bootHintLocal =>
      '若卡在白屏或連不上：系統設定 → 隱私與安全性 → 本機網路 → 打開本 App；\n真機請在 assets/config/dev.local.json（從 *.example 複製）把 api_base_url 設為 http://<電腦區網IP>:8000。';
}
