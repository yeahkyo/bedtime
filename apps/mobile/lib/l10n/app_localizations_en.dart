// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Huhu · Pillow Tales';

  @override
  String get meTitle => 'Me';

  @override
  String get tabStories => 'Stories';

  @override
  String get meSettings => 'Settings';

  @override
  String get meVoicesTitle => 'Voices';

  @override
  String get meVoicesSubtitleClone => 'System voices and parent voice clone';

  @override
  String get meVoicesSubtitle => 'System reading voices';

  @override
  String get meCharactersTitle => 'Characters';

  @override
  String get meCharactersSubtitle => 'Listeners and story cast';

  @override
  String get meLanguageTitle => 'Language';

  @override
  String meLanguageSubtitle(String label) {
    return '$label';
  }

  @override
  String get meAboutTitle => 'About';

  @override
  String get meAboutSubtitle => 'Product and contact';

  @override
  String get meTermsTitle => 'Terms of Service';

  @override
  String get meTermsSubtitle => 'User agreement';

  @override
  String get mePrivacyTitle => 'Privacy Policy';

  @override
  String get mePrivacySubtitle => 'How we handle your data';

  @override
  String meVersion(String version) {
    return 'Version $version';
  }

  @override
  String get meLogoutAccount => 'Log out of this account';

  @override
  String meBrandFooter(String version) {
    return 'Huhu · Pillow Tales  Version v$version';
  }

  @override
  String get languagePickerTitle => 'Language';

  @override
  String get languageZhHans => '简体中文';

  @override
  String get languageZhHant => '繁體中文';

  @override
  String get languageEn => 'English';

  @override
  String get profileGuest => 'Not signed in';

  @override
  String get profileGuestHint => 'Sign in to sync stories and voices';

  @override
  String get profileConnected => 'Connected to bedtime service';

  @override
  String get profileDefaultName => 'Bedtime parent';

  @override
  String get profileLogin => 'Sign in';

  @override
  String get profileLogout => 'Sign out';

  @override
  String get profileRefresh => 'Refresh';

  @override
  String quotaStories(Object used, Object limit) {
    return 'Stories this month $used/$limit';
  }

  @override
  String quotaCloneSuffix(Object used, Object limit) {
    return ' · Clones $used/$limit';
  }

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutTagline => 'Gentle bedtime stories for little listeners';

  @override
  String get aboutVersionLabel => 'Version';

  @override
  String get aboutDeveloperLabel => 'Developer';

  @override
  String get aboutDeveloperName => 'Lullvale Studio';

  @override
  String get aboutSupportLabel => 'Support';

  @override
  String get aboutWebsiteLabel => 'Website';

  @override
  String get aboutTermsLink => 'Terms of Service';

  @override
  String get aboutPrivacyLink => 'Privacy';

  @override
  String aboutCopyright(int year) {
    return '© $year Lullvale';
  }

  @override
  String get termsTitle => 'Terms of Service';

  @override
  String get privacyTitle => 'Privacy Policy';

  @override
  String get legalOpenFailed => 'Could not open the link.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'OK';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonSave => 'Save';

  @override
  String get commonClose => 'Close';

  @override
  String get commonUnnamed => 'Unnamed';

  @override
  String get commonLoading => 'Loading';

  @override
  String get genderUnspecified => 'Not specified';

  @override
  String get genderBoy => 'Boy';

  @override
  String get genderGirl => 'Girl';

  @override
  String get genderOther => 'Other';

  @override
  String get homeOfflineSnackbar =>
      'Offline mode: showing cached content. It will sync when you\'re back online.';

  @override
  String get authBrandName => 'Huhu';

  @override
  String get authBrandBadge => 'Pillow Tales';

  @override
  String get authSubtitleLogin => 'Sign in to continue your bedtime stories';

  @override
  String get authSubtitleRegister => 'Create an account with an invite code';

  @override
  String get authInviteCode => 'Invite code';

  @override
  String get authNicknameOptional => 'Display name (optional)';

  @override
  String get authPhone => 'Phone number';

  @override
  String get authPassword => 'Password';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authLoginSms => 'Sign in with code';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authSubmitLogin => 'Sign in';

  @override
  String get authSubmitRegister => 'Register & sign in';

  @override
  String get authHaveAccount => 'Already have an account? ';

  @override
  String get authHaveInvite => 'Have an invite code? ';

  @override
  String get authGoLogin => 'Sign in';

  @override
  String get authGoRegister => 'Register';

  @override
  String get authNightHint => 'Low blue light for night · Sweet dreams';

  @override
  String get authAgreeRegisterPrefix => 'By registering, you agree to the ';

  @override
  String get authAgreeLoginPrefix => 'By signing in, you agree to the ';

  @override
  String get authTermsLink => 'Terms of Service';

  @override
  String get authAnd => ' and ';

  @override
  String get authPrivacyLink => 'Privacy Policy';

  @override
  String get authPrivacyLinkRegister => 'Privacy Policy';

  @override
  String get authErrorInviteRequired => 'Please enter an invite code';

  @override
  String get authErrorPhoneRequired => 'Please enter a phone number';

  @override
  String get authErrorPasswordShort => 'Password must be at least 8 characters';

  @override
  String get authErrorPasswordMismatch => 'Passwords do not match';

  @override
  String get authErrorPasswordRequired => 'Please enter a password';

  @override
  String get authErrorInvalidResponse => 'Invalid sign-in response';

  @override
  String authComingSoon(String feature) {
    return '$feature is not available yet. Stay tuned.';
  }

  @override
  String get authFeatureSmsLogin => 'Sign-in with code';

  @override
  String get authFeatureRecoverPassword => 'Password recovery';

  @override
  String get storyProgressQueued => 'In queue…';

  @override
  String get storyProgressSeriesOutline => 'Outlining the series…';

  @override
  String get storyProgressEpisodePlan => 'Planning tonight\'s plot…';

  @override
  String get storyProgressDraft => 'Writing the story…';

  @override
  String get storyProgressTts => 'Generating narration audio…';

  @override
  String get storyProgressReady => 'Done';

  @override
  String get storyProgressReadyPlay => 'Done — ready to play…';

  @override
  String get storyProgressFailed => 'Generation failed';

  @override
  String storyProgressGenerating(String progress) {
    return 'Generating ($progress)…';
  }

  @override
  String get storyGenerateFailed => 'Story generation failed';

  @override
  String get storyGenerateFailedRetry =>
      'Story generation failed. You can retry.';

  @override
  String get storyStillGenerating =>
      'Still generating — pull to refresh, then listen';

  @override
  String get storyNoAudio => 'No audio available to play';

  @override
  String get storyNoAudioShort => 'No audio yet';

  @override
  String get storyCreateFailed => 'Could not create story';

  @override
  String get storyRetrying => 'Regenerating…';

  @override
  String get storyResumeWaiting => 'Still waiting for generation…';

  @override
  String get storyContinueWaiting => 'Keep waiting';

  @override
  String get storyContinuingEpisode => 'Writing the next episode…';

  @override
  String get storySubmittedQueued => 'Submitted — in queue…';

  @override
  String get storiesTitle => 'Stories';

  @override
  String get storiesStatusWaitingFirst => 'Waiting for the first one';

  @override
  String get storiesStatusReady => 'Night light ready';

  @override
  String get storiesCreateEyebrow => 'Dream engine · New chapter';

  @override
  String get storiesCreateTitle => 'Create tonight\'s story';

  @override
  String get storiesCreateSubtitle => 'Custom cast, plot, and soothing audio';

  @override
  String get storiesLibraryTitle => 'Pillow tale bookshelf';

  @override
  String get storiesLibraryEmpty => 'No stories yet';

  @override
  String storiesLibraryCount(int count) {
    return 'Newest first · $count stories';
  }

  @override
  String get storiesEmptyShelfTitle => 'An empty shelf';

  @override
  String get storiesEmptyShelfBody =>
      'Tonight\'s first little book is waiting — tap the golden card above.';

  @override
  String get storiesUntitled => 'Unfinished story';

  @override
  String get storiesFailedRetry => 'Generation failed · Retry available';

  @override
  String storiesFailedWithError(String error) {
    return 'Failed · $error';
  }

  @override
  String get storiesSeriesContinueHint =>
      'To continue a series, start again from Create';

  @override
  String storiesMinutes(Object minutes) {
    return '$minutes min';
  }

  @override
  String storiesSeriesMeta(Object id) {
    return 'Series #$id';
  }

  @override
  String storiesEpisodeMeta(Object ep) {
    return ' Ep. $ep';
  }

  @override
  String get creatingTitle => 'Creating';

  @override
  String get creatingBackTooltip => 'Back to stories';

  @override
  String get creatingHeadlineOk => 'Writing tonight\'s story';

  @override
  String get creatingHeadlineFail => 'This one didn\'t finish';

  @override
  String get creatingBodyOk =>
      'The cloud is writing the text and recording narration — usually a minute or two.';

  @override
  String get creatingBodyFail =>
      'You can retry, or go back to the list and open this story later.';

  @override
  String get creatingHintsOkTitle => 'While it generates';

  @override
  String get creatingHintsFailTitle => 'What you can do next';

  @override
  String get creatingHintAutoPlay =>
      'When it\'s done, you\'ll open the player and start listening automatically.';

  @override
  String get creatingHintCloud =>
      'Creation continues in the cloud — closing this page is fine.';

  @override
  String get creatingHintList =>
      'Return to Stories anytime to check progress or listen later.';

  @override
  String get creatingHintRetry =>
      'Tap retry below to continue this story without using extra quota.';

  @override
  String get creatingHintBackLater =>
      'Or go back to the list and open or retry later.';

  @override
  String get creatingRetry => 'Regenerate';

  @override
  String get creatingRetrying => 'Retrying…';

  @override
  String get creatingBackFailed => 'Back to stories';

  @override
  String get creatingBackOk => 'Back to stories for now';

  @override
  String get voicesManageTitle => 'Voices';

  @override
  String get voicesManageEyebrow => 'Huhu · Voice';

  @override
  String get voicesManageHeaderTitle => 'My voices';

  @override
  String get voicesManageSubtitleClone =>
      'Manage narration voices, or clone a parent\'s voice for bedtime stories';

  @override
  String get voicesManageSubtitleSystem =>
      'Manage system narration voices — preview and pick one';

  @override
  String get voicesManageCloneCta => 'Clone a new voice';

  @override
  String get voicesManageSectionTitle => 'Saved voices';

  @override
  String get voicesManageNone => 'No voices yet';

  @override
  String voicesManageCount(int count) {
    return '$count voices · Preview available';
  }

  @override
  String get voicesManageEmptyCloneHint =>
      'Tap the button above to clone a parent\'s voice.';

  @override
  String get voicesManageEmptySystemHint =>
      'No system voices available. Try again later or contact support.';

  @override
  String get voicesKindClone => 'Cloned voice';

  @override
  String get voicesKindSystem => 'System voice';

  @override
  String get voicesPreviewUnavailable => 'No preview';

  @override
  String get voicesPreviewUnavailableSnack =>
      'Preview isn\'t available for this voice yet. Try again later.';

  @override
  String get voicesPreviewUnavailableShort => 'No preview for this voice';

  @override
  String get voicesPreviewFailed => 'Couldn\'t play preview';

  @override
  String get voicesPreviewPlay => 'Preview';

  @override
  String get voicesPreviewStop => 'Stop preview';

  @override
  String get voicesPreviewStopShort => 'Stop';

  @override
  String get voicesNoPreviewSuffix => ' · No preview';

  @override
  String get voiceCloneTitle => 'Clone a new voice';

  @override
  String get voiceCloneEyebrow => 'Huhu · Clone';

  @override
  String get voiceCloneHeaderTitle => 'Record a parent\'s voice';

  @override
  String get voiceCloneHeaderSubtitle =>
      'In a quiet place, read for about 10–15 seconds. The clone can narrate bedtime stories.';

  @override
  String get voiceCloneNameSection => 'Voice name';

  @override
  String get voiceCloneNameHint => 'e.g. Mom\'s voice, Dad\'s bedtime voice';

  @override
  String get voiceCloneDefaultName => 'Parent voice';

  @override
  String get voiceCloneUsageTitle => 'How it works';

  @override
  String get voiceCloneUsageBody =>
      'Original recordings are deleted soon after upload. Once cloned, you can pick this voice when creating stories.';

  @override
  String get voiceCloneConsent =>
      'I agree to use my voice for bedtime story narration in this app';

  @override
  String get voiceCloneScriptTitle => 'Please read this aloud';

  @override
  String get voiceCloneScriptSubtitle =>
      'You may read both Chinese and English once; a natural pace is fine';

  @override
  String get voiceCloneScriptZh =>
      'Tonight I\'ll tell a gentle bedtime story in a soft voice. The wind is light, the moon is bright, and we slowly close our eyes.';

  @override
  String get voiceCloneStartRecord => 'Start recording';

  @override
  String get voiceCloneStopRecord => 'Stop recording';

  @override
  String get voiceCloneRerecord => 'Record again';

  @override
  String get voiceCloneRecordingHint => 'Recording… tap stop when you\'re done';

  @override
  String get voiceCloneReadyHint =>
      'Sample ready — confirm the name and consent, then upload to clone';

  @override
  String get voiceCloneUpload => 'Upload & clone';

  @override
  String get voiceCloneUploading => 'Uploading…';

  @override
  String get voiceCloneNeedMic => 'Microphone permission is required';

  @override
  String get voiceCloneNeedName => 'Please enter a voice name';

  @override
  String get voiceCloneNeedConsent => 'Please accept the consent checkbox';

  @override
  String get voiceCloneSuccess =>
      'Clone ready — you can use it when creating stories';

  @override
  String get voicePickerTitle => 'Choose a voice';

  @override
  String get voicePickerHint => 'Preview, then confirm to use';

  @override
  String get voicePickerUse => 'Use this voice';

  @override
  String get voicePickerEmpty => 'None';

  @override
  String get voicePickerUnnamed => 'Unnamed voice';

  @override
  String get childrenManageTitle => 'Characters';

  @override
  String get childrenManageTagline =>
      'Dream cast book · Tailored bedtime tales';

  @override
  String get childrenTabListeners => 'Listeners';

  @override
  String get childrenTabPeople => 'Family & friends';

  @override
  String get childrenTabToys => 'Toy pals';

  @override
  String get childrenFabListener => 'Add a listener';

  @override
  String get childrenFabPeople => 'Add family or friend';

  @override
  String get childrenFabToy => 'Add a toy pal';

  @override
  String get childrenEmptyListenersTitle => 'No listeners yet';

  @override
  String get childrenEmptyListenersBody =>
      'Add a listener profile first to create stories and attach family or toys.';

  @override
  String get childrenEmptyListenersCta => 'Add your first listener';

  @override
  String get childrenEmptyPeopleTitle => 'No family or friends yet';

  @override
  String get childrenEmptyPeopleBody =>
      'Add grandparents, classmates, and more so they can appear in stories.';

  @override
  String get childrenEmptyToysTitle => 'No toy pals yet';

  @override
  String get childrenEmptyToysBody =>
      'Add dolls and plush friends so they can appear in stories.';

  @override
  String get childrenNeedListenerFirst => 'Please add a listener first';

  @override
  String get childrenSheetTitle => 'Listener profile';

  @override
  String get childrenNickname => 'Nickname';

  @override
  String get childrenGender => 'Gender';

  @override
  String get childrenBirthday => 'Birthday';

  @override
  String get childrenPickBirthday => 'Choose birthday';

  @override
  String get childrenBirthdayHint => 'YYYY/MM/DD';

  @override
  String get childrenIntroOptional => 'Bio (optional)';

  @override
  String get childrenIntroHint => 'Personality, recent mood…';

  @override
  String get childrenPreferLabel => 'Story preferences (comma-separated)';

  @override
  String get childrenPreferHint =>
      'Dinosaur adventures, gentle fairy tales, a touch of humor';

  @override
  String get childrenAddToy => 'Add toy';

  @override
  String get childrenEditToy => 'Edit toy';

  @override
  String get childrenAddPerson => 'Add family / friend';

  @override
  String get childrenEditPerson => 'Edit family / friend';

  @override
  String get childrenToyName => 'Name';

  @override
  String get childrenPersonName => 'Name / title';

  @override
  String get childrenToyNameHint => 'Star doll';

  @override
  String get childrenPersonNameHint => 'Grandpa';

  @override
  String get childrenBelongsTo => 'Belongs to';

  @override
  String get childrenLinkedListener => 'Linked listener';

  @override
  String get childrenRelation => 'Relation';

  @override
  String get childrenRelationHint => 'Grandpa / classmate / teacher…';

  @override
  String get childrenToyNote => 'Look / temperament (optional)';

  @override
  String get childrenPersonNote => 'Traits (optional)';

  @override
  String get childrenToyNoteHint => 'Blue ears, loves to sing';

  @override
  String get childrenPersonNoteHint => 'Loves telling stories';

  @override
  String get childrenDeleteListenerTitle => 'Delete this listener?';

  @override
  String childrenDeleteListenerBody(String name) {
    return 'This will also delete family and toy characters under “$name”.';
  }

  @override
  String childrenDeleted(String name) {
    return 'Deleted “$name”';
  }

  @override
  String get childrenDeleteCharacterTitle => 'Delete this character?';

  @override
  String childrenDeleteCharacterBody(String name) {
    return 'After deleting “$name”, you won\'t be able to select them when creating stories.';
  }

  @override
  String get childrenDefaultCharacter => 'Character';

  @override
  String get childrenTagListener => 'Listener';

  @override
  String get childrenTagToy => 'Comfort plush';

  @override
  String get childrenTagPeople => 'Family & friends';

  @override
  String childrenPreferPrefix(String prefs) {
    return 'Likes: $prefs';
  }

  @override
  String get childrenEditPrefs => 'Edit profile & bedtime prefs';

  @override
  String get childrenSleepPreset => 'Sleep preset';

  @override
  String childrenBelongsToName(String name) {
    return 'Belongs to $name';
  }

  @override
  String childrenToySubtitle(String name) {
    return 'Bedside pal · Belongs to $name';
  }

  @override
  String childrenPersonalityPrefix(String note) {
    return 'Personality: $note';
  }

  @override
  String get childrenUnlinked => 'Unlinked';

  @override
  String childrenChildFallback(int id) {
    return 'Child #$id';
  }

  @override
  String get childrenMagicTitle => 'Character magic';

  @override
  String get childrenMagicBody =>
      'The dream engine uses the lead\'s age and preferences to weave gentle lines and a soothing bedtime rhythm into each night\'s soundscape.';

  @override
  String get createStoryTitle => 'Customize tonight\'s story';

  @override
  String get createStoryNeedListenerTitle => 'Add a listener first';

  @override
  String get createStoryNeedListenerSubtitle =>
      'With a child profile, you can customize tonight\'s story';

  @override
  String get createStoryNoRolesTitle => 'No characters yet';

  @override
  String get createStoryNoRolesBody =>
      'Create a child profile (nickname, age, and more). Then come back to generate a story.';

  @override
  String get createStoryGoAddChild => 'Add a child profile';

  @override
  String get createStoryGenerate => 'Generate tonight\'s story';

  @override
  String get createStoryGenerating => 'Generating…';

  @override
  String get createStoryQuotaPrefix => 'Stories this month ';

  @override
  String createStoryQuotaLine(Object used, Object limit) {
    return 'Stories this month $used/$limit';
  }

  @override
  String get createStoryListenersTitle => 'Who is listening tonight?';

  @override
  String get createStoryListenersSubMulti =>
      'Multi-select allowed; the story weaves from listeners\' preferences';

  @override
  String get createStoryListenersSubSingle =>
      'The story weaves from the listener\'s preferences';

  @override
  String get createStoryManageListeners => 'Manage listener profiles';

  @override
  String get createStoryPrimaryListener => 'Primary listener';

  @override
  String get createStoryNoPrefer =>
      'No preferences yet · Soft bedtime fairy tales';

  @override
  String get createStoryOptionsTitle => 'What story tonight?';

  @override
  String get createStoryOptionsSubtitle =>
      'We\'ll create from these ingredients';

  @override
  String get createStoryInspiration => 'Story spark';

  @override
  String get createStoryInspirationHint =>
      'Optional — you can leave this blank';

  @override
  String get createStoryThemeHint =>
      'What to tell tonight (optional), e.g. a kitten watching stars on a cloud…';

  @override
  String get createStoryCastTitle => 'Appearing tonight';

  @override
  String get createStoryAddCharacter => 'Add character';

  @override
  String get createStoryCastEmpty =>
      'Add listeners, family, or toys in Characters.';

  @override
  String get createStoryCharacterFallback => 'Character';

  @override
  String get createStoryType => 'Story type';

  @override
  String get createStoryVoice => 'Narration voice';

  @override
  String createStoryVoiceSelected(String name) {
    return 'Selected: $name';
  }

  @override
  String get createStoryVoiceNone => 'No voice selected';

  @override
  String get createStoryVoicePick => 'Choose a voice';

  @override
  String get createStoryVoiceChange => 'Change';

  @override
  String get createStoryMoreOptions => 'More options (language & dialogue)';

  @override
  String get createStoryLanguage => 'Narration language';

  @override
  String get createStoryLangZh => 'Chinese';

  @override
  String get createStoryEnglishSoon =>
      'English stories aren\'t available yet. Stay tuned.';

  @override
  String get createStoryDialogue => 'How much dialogue';

  @override
  String get createStoryTypeEveryday => 'Everyday life';

  @override
  String get createStoryTypeSoft => 'A touch of imagination';

  @override
  String get createStoryTypeFantasy => 'Wonderful worlds';

  @override
  String get createStoryDialogueLow => 'Very little dialogue';

  @override
  String get createStoryDialogueSome => 'A little dialogue';

  @override
  String get createStoryDialogueMore => 'More dialogue';

  @override
  String get createStorySoftSeries => 'Soft series (continuable)';

  @override
  String get createStorySoftHook => 'Previous soft hook (optional)';

  @override
  String get createStoryEpisodeNo => 'Episode number';

  @override
  String get createStoryDreamRules => 'Dream rules';

  @override
  String get createStoryDreamRulesBody =>
      'The story gently settles into a calm rhythm, then fades into goodnight white noise.';

  @override
  String get createStoryDuration => 'Length (minutes)';

  @override
  String get createStoryErrAddChild => 'Please add a child profile first';

  @override
  String get createStoryErrNickname =>
      'Please finish the child\'s nickname (tap the profile card to edit)';

  @override
  String get createStoryErrVoice =>
      'Please choose a voice (or create a system voice on the Voices page)';

  @override
  String get createStoryErrListener =>
      'Please choose tonight\'s listener first';

  @override
  String get playerTitle => 'Co-read';

  @override
  String get playerStatusLive => 'Bedside lamp · Night play on';

  @override
  String get playerModePicture => 'Picture book';

  @override
  String get playerModeAudio => 'Listen only';

  @override
  String get playerWarmLight => 'Pillow glow';

  @override
  String get playerBrandLine => 'Huhu · Pillow Tales';

  @override
  String get playerCoRead => 'Parent–child co-reading';

  @override
  String get playerFullText => 'Full text';

  @override
  String get playerFollowAlong => 'Words glide along';

  @override
  String get playerCollapse => 'Collapse';

  @override
  String get playerExpand => 'View full text';

  @override
  String get playerSpeedTitle => 'Narration speed';

  @override
  String get playerSpeedHint =>
      'Changes story narration only. Background music is unchanged. Audio is not re-synthesized.';

  @override
  String playerSpeedCurrent(String speed) {
    return 'Current $speed×';
  }

  @override
  String playerBedTrack(String label) {
    return 'Cradle bed sound · $label';
  }

  @override
  String get playerBedMusicBox => 'Music box';

  @override
  String playerRemain(String time) {
    return 'Left $time';
  }

  @override
  String get playerBedFading => 'Bed sound is fading out';

  @override
  String get playerOutroOff => 'Turn off sleep music when the story ends';

  @override
  String playerOutroMinutes(int minutes) {
    return 'Play $minutes more minutes after the story';
  }

  @override
  String get playerOutroOffShort => 'Off now';

  @override
  String playerOutroMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get playerBedOff => 'Off';

  @override
  String get playerScript => 'Script';

  @override
  String get playerTimerTitle => 'Timer for music';

  @override
  String get playerTimerSubtitle =>
      'Delay turning off sleep music after the story ends';

  @override
  String playerTimerFading(String time) {
    return 'Sleep music fading · $time left';
  }

  @override
  String get playerTimerDelay => 'Delay';

  @override
  String get createStoryDurationMood3 => '3 min · short nap';

  @override
  String get createStoryDurationMood5 => '5 min · ready for sleep';

  @override
  String get createStoryDurationMood8 => '8 min · warm immersion';

  @override
  String get createStoryDurationMood10 => '10 min · long fairy tale';

  @override
  String get createStoryDurationMood12 => '12 min · deep rest';

  @override
  String createStoryDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get playerOutroMood0 => '0 min · stop when story ends';

  @override
  String get playerOutroMood1 => '1 min · soft afterglow';

  @override
  String get playerOutroMood5 => '5 min · gentle wind-down';

  @override
  String get playerOutroMood10 => '10 min · slowly quiet';

  @override
  String get playerOutroMood15 => '15 min · sleep echoes';

  @override
  String get playerOutroMood30 => '30 min · all-night companion';

  @override
  String playerOutroMoodMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String ageYears(int years) {
    return '$years years old';
  }

  @override
  String ageYearsMonths(int years, int months) {
    return '$years years $months months';
  }

  @override
  String get commonPleaseSelect => 'Please select';

  @override
  String get storiesContinueEpisodeTooltip => 'Continue next episode';

  @override
  String get netTimeout => 'Network timed out. Please try again later.';

  @override
  String get netOfflineCached => 'Network unavailable. Showing local cache.';

  @override
  String get apiSessionExpired => 'Session expired. Please sign in again.';

  @override
  String get apiRefreshFailed => 'Could not refresh sign-in.';

  @override
  String get apiStoryGenerateFailed => 'Story generation failed';

  @override
  String get apiStoryCreateFailed => 'Could not create the story';

  @override
  String get apiStoryWaitNetworkUnstable =>
      'Network is unstable; generation may still be running. Refresh Stories later, or tap Continue waiting.';

  @override
  String get apiStoryWaitTimeout =>
      'Network timed out; generation may still be running. Refresh later or tap Continue waiting.';

  @override
  String get apiStoryWaitOffline =>
      'Network unavailable; generation may still be running. When back online, tap Continue waiting.';

  @override
  String get apiStoryWaitDeadline =>
      'Timed out waiting for the story. Check Stories to see if it finished.';

  @override
  String get apiNetworkUnstableRetry =>
      'Network is unstable. Please try again later.';

  @override
  String get apiForbidden => 'You don’t have permission for this action';

  @override
  String get apiNotFound => 'Content not found';

  @override
  String get apiTooManyRequests => 'Too many requests. Please try again later.';

  @override
  String get apiServerUnavailable =>
      'Service temporarily unavailable. Please try again later.';

  @override
  String apiRequestFailed(int statusCode) {
    return 'Request failed ($statusCode)';
  }

  @override
  String get bootCannotConnect => 'Can\'t connect';

  @override
  String get bootRetry => 'Retry';

  @override
  String get bootHintRemote =>
      'For staging/online, use the Cloudflare HTTPS host:\n--dart-define=API_BASE_URL=https://bedtime-api.<your-domain>\nand register with an invite code or sign in with phone.';

  @override
  String get bootHintLocal =>
      'If the screen stays blank or won\'t connect: Settings → Privacy & Security → Local Network → enable this app;\nand launch with --dart-define=API_BASE_URL=http://<your-Mac-LAN-IP>:8000.';
}
