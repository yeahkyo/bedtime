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
  String get meVoicesSubtitleClone => 'System voices and parent voice clones';

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
  String get meTermsSubtitle => 'Legal terms';

  @override
  String get mePrivacyTitle => 'Privacy Policy';

  @override
  String get mePrivacySubtitle => 'How we use your data';

  @override
  String meVersion(String version) {
    return 'Version $version';
  }

  @override
  String get meLogoutAccount => 'Log out of this account';

  @override
  String meBrandFooter(String version) {
    return 'Huhu · Pillow Tales · v$version';
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
  String get profileConnected => 'Connected';

  @override
  String get profileDefaultName => 'Parent';

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
  String get legalOpenFailed => 'Couldn\'t open the link.';

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
  String get genderUnspecified => 'Prefer not to say';

  @override
  String get genderBoy => 'Boy';

  @override
  String get genderGirl => 'Girl';

  @override
  String get genderOther => 'Other';

  @override
  String get homeOfflineSnackbar =>
      'You\'re offline. Showing saved stories — they\'ll sync when you\'re back online.';

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
  String get authNightHint => 'Designed for night · Sweet dreams';

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
  String get authErrorInvalidResponse =>
      'Something went wrong signing in. Please try again.';

  @override
  String authComingSoon(String feature) {
    return '$feature isn\'t available yet. Stay tuned.';
  }

  @override
  String get authFeatureSmsLogin => 'Sign-in with code';

  @override
  String get authFeatureRecoverPassword => 'Password recovery';

  @override
  String get authClose => 'Close';

  @override
  String get storyProgressQueued => 'In queue…';

  @override
  String get storyProgressSeriesOutline => 'Outlining the series…';

  @override
  String get storyProgressEpisodePlan => 'Planning tonight\'s story…';

  @override
  String get storyProgressDraft => 'Writing the story…';

  @override
  String get storyProgressTts => 'Recording the narration…';

  @override
  String get storyProgressReady => 'Done';

  @override
  String get storyProgressReadyPlay => 'Done — ready to play…';

  @override
  String get storyProgressFailed => 'Couldn\'t finish';

  @override
  String storyProgressGenerating(String progress) {
    return 'Creating ($progress)…';
  }

  @override
  String get storyGenerateFailed => 'Couldn\'t create this story';

  @override
  String get storyGenerateFailedRetry =>
      'Couldn\'t create this story. You can try again.';

  @override
  String get storyStillGenerating =>
      'Still creating — pull to refresh, then listen';

  @override
  String get storyNoAudio => 'No audio to play yet';

  @override
  String get storyNoAudioShort => 'No audio yet';

  @override
  String get storyCreateFailed => 'Couldn\'t start this story';

  @override
  String get storyRetrying => 'Trying again…';

  @override
  String get storyResumeWaiting => 'Still creating…';

  @override
  String get storyContinueWaiting => 'Keep waiting';

  @override
  String get storyContinuingEpisode => 'Writing the next episode…';

  @override
  String get storySubmittedQueued => 'Submitted — in queue…';

  @override
  String get storiesTitle => 'Stories';

  @override
  String get storiesStatusWaitingFirst => 'Waiting for the first story';

  @override
  String get storiesStatusReady => 'Ready for bedtime';

  @override
  String get storiesCreateEyebrow => 'Tonight';

  @override
  String get storiesCreateTitle => 'Create tonight\'s story';

  @override
  String get storiesCreateSubtitle => 'Your cast, plot, and bedtime audio';

  @override
  String get storiesLibraryTitle => 'Your stories';

  @override
  String get storiesLibraryEmpty => 'No stories yet';

  @override
  String storiesLibraryCount(int count) {
    return 'Newest first · $count stories';
  }

  @override
  String get storiesEmptyShelfTitle => 'Your shelf is empty';

  @override
  String get storiesEmptyShelfBody =>
      'Tap the card above to make tonight\'s first story.';

  @override
  String get storiesUntitled => 'Untitled story';

  @override
  String get storiesFailedRetry => 'Failed · Tap to retry';

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
  String get storiesLengthShort => 'Short';

  @override
  String get storiesLengthMedium => 'Medium';

  @override
  String get storiesLengthLong => 'Long';

  @override
  String storiesLengthLabel(String label, Object minutes) {
    return '$label · ~$minutes min';
  }

  @override
  String storiesSeriesMeta(Object id) {
    return 'Series $id';
  }

  @override
  String storiesEpisodeMeta(Object ep) {
    return ' · Ep. $ep';
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
  String creatingBodyOk(String eta) {
    return 'We\'re writing the story and recording the narration — usually $eta.';
  }

  @override
  String get creatingWaitEtaShort => '1–2 minutes';

  @override
  String get creatingWaitEtaMedium => '2–3 minutes';

  @override
  String get creatingWaitEtaLong => '6–7 minutes';

  @override
  String get creatingBodyFail =>
      'You can try again, or go back and open this story later.';

  @override
  String get creatingHintsOkTitle => 'While you wait';

  @override
  String get creatingHintsFailTitle => 'What you can do';

  @override
  String get creatingHintAutoPlay =>
      'When it\'s ready, you\'ll open the player and start listening.';

  @override
  String get creatingHintCloud =>
      'It keeps going in the cloud — you can leave this page.';

  @override
  String get creatingHintList =>
      'Check Stories anytime for progress, or listen later.';

  @override
  String get creatingHintRetry =>
      'Retry below to continue this story — it won\'t use extra quota.';

  @override
  String get creatingHintBackLater =>
      'Or go back to the list and open or retry later.';

  @override
  String get creatingRetry => 'Try again';

  @override
  String get creatingRetrying => 'Retrying…';

  @override
  String get creatingBackFailed => 'Back to stories';

  @override
  String get creatingBackOk => 'Back to stories';

  @override
  String get voicesManageTitle => 'Voices';

  @override
  String get voicesManageEyebrow => 'Huhu · Voice';

  @override
  String get voicesManageHeaderTitle => 'My voices';

  @override
  String get voicesManageSubtitleClone =>
      'Preview voices, or clone a parent\'s voice';

  @override
  String get voicesManageSubtitleSystem => 'Preview and pick a system voice';

  @override
  String get voicesManageCloneCta => 'Clone a voice';

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
      'Tap above to clone a parent\'s voice.';

  @override
  String get voicesManageEmptySystemHint =>
      'No system voices right now. Try again later.';

  @override
  String get voicesKindClone => 'Cloned voice';

  @override
  String get voicesKindSystem => 'System voice';

  @override
  String get voicesPreviewUnavailable => 'No preview';

  @override
  String get voicesPreviewUnavailableSnack =>
      'Preview isn\'t ready for this voice yet.';

  @override
  String get voicesPreviewUnavailableShort => 'No preview';

  @override
  String get voicesPreviewFailed => 'Couldn\'t play preview';

  @override
  String get voicesPreviewPlay => 'Preview';

  @override
  String get voicesPreviewStop => 'Stop';

  @override
  String get voicesPreviewStopShort => 'Stop';

  @override
  String get voicesNoPreviewSuffix => ' · No preview';

  @override
  String get voiceCloneTitle => 'Clone a voice';

  @override
  String get voiceCloneEyebrow => 'Huhu · Clone';

  @override
  String get voiceCloneHeaderTitle => 'Record a parent\'s voice';

  @override
  String get voiceCloneHeaderSubtitle =>
      'In a quiet spot, read for about 10–15 seconds.';

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
      'We delete the original recording soon after upload. Then you can use this voice for bedtime stories.';

  @override
  String get voiceCloneConsent =>
      'I agree to use my voice for bedtime stories in this app';

  @override
  String get voiceCloneScriptTitle => 'Please read this aloud';

  @override
  String get voiceCloneScriptSubtitle =>
      'A natural pace is fine — Chinese or English is OK';

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
      'Sample ready — name it, agree, then upload';

  @override
  String get voiceCloneUpload => 'Upload & clone';

  @override
  String get voiceCloneUploading => 'Uploading…';

  @override
  String get voiceCloneNeedMic => 'Microphone access is required';

  @override
  String get voiceCloneNeedName => 'Please enter a voice name';

  @override
  String get voiceCloneNeedConsent => 'Please check the consent box';

  @override
  String get voiceCloneSuccess =>
      'Voice ready — you can use it when creating stories';

  @override
  String get voicePickerTitle => 'Choose a voice';

  @override
  String get voicePickerHint => 'Preview, then confirm';

  @override
  String get voicePickerUse => 'Use this voice';

  @override
  String get voicePickerEmpty => 'None';

  @override
  String get voicePickerUnnamed => 'Unnamed voice';

  @override
  String get childrenManageTitle => 'Characters';

  @override
  String get childrenManageTagline => 'Listeners and cast for bedtime stories';

  @override
  String get childrenTabListeners => 'Listeners';

  @override
  String get childrenTabPeople => 'Family & friends';

  @override
  String get childrenTabToys => 'Toys';

  @override
  String get childrenFabListener => 'Add a listener';

  @override
  String get childrenFabPeople => 'Add family or friend';

  @override
  String get childrenFabToy => 'Add a toy';

  @override
  String get childrenEmptyListenersTitle => 'No listeners yet';

  @override
  String get childrenEmptyListenersBody =>
      'Add a listener first so you can create stories and link family or toys.';

  @override
  String get childrenEmptyListenersCta => 'Add your first listener';

  @override
  String get childrenEmptyPeopleTitle => 'No family or friends yet';

  @override
  String get childrenEmptyPeopleBody =>
      'Add grandparents, classmates, and others so they can appear in stories.';

  @override
  String get childrenEmptyToysTitle => 'No toys yet';

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
  String get childrenPreferLabel => 'Story preferences';

  @override
  String get childrenPreferHint =>
      'Dinosaur adventures, gentle fairy tales, a bit of humor';

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
  String get childrenToyNote => 'Look / personality (optional)';

  @override
  String get childrenPersonNote => 'Notes (optional)';

  @override
  String get childrenToyNoteHint => 'Blue ears, loves to sing';

  @override
  String get childrenPersonNoteHint => 'Loves telling stories';

  @override
  String get childrenDeleteListenerTitle => 'Delete this listener?';

  @override
  String childrenDeleteListenerBody(String name) {
    return 'This also deletes family and toy characters under “$name”.';
  }

  @override
  String childrenDeleted(String name) {
    return 'Deleted “$name”';
  }

  @override
  String get childrenDeleteCharacterTitle => 'Delete this character?';

  @override
  String childrenDeleteCharacterBody(String name) {
    return 'After deleting “$name”, you won\'t be able to pick them in new stories.';
  }

  @override
  String get childrenDefaultCharacter => 'Character';

  @override
  String get childrenTagListener => 'Listener';

  @override
  String get childrenTagToy => 'Toy';

  @override
  String get childrenTagPeople => 'Family & friends';

  @override
  String childrenPreferPrefix(String prefs) {
    return 'Likes: $prefs';
  }

  @override
  String get childrenEditPrefs => 'Edit profile';

  @override
  String get childrenSleepPreset => 'Sleep preset';

  @override
  String childrenBelongsToName(String name) {
    return 'Belongs to $name';
  }

  @override
  String childrenToySubtitle(String name) {
    return 'Bedside pal · $name';
  }

  @override
  String childrenPersonalityPrefix(String note) {
    return 'Notes: $note';
  }

  @override
  String get childrenUnlinked => 'Unlinked';

  @override
  String childrenChildFallback(int id) {
    return 'Child #$id';
  }

  @override
  String get childrenMagicTitle => 'Why profiles help';

  @override
  String get childrenMagicBody =>
      'We use age and preferences to keep each story gentle, familiar, and ready for bedtime.';

  @override
  String get createStoryTitle => 'Tonight\'s story';

  @override
  String get createStoryNeedListenerTitle => 'Add a listener first';

  @override
  String get createStoryNeedListenerSubtitle =>
      'A listener profile lets you customize tonight\'s story';

  @override
  String get createStoryNoRolesTitle => 'No characters yet';

  @override
  String get createStoryNoRolesBody =>
      'Add a listener (nickname, age, and more), then come back to create a story.';

  @override
  String get createStoryGoAddChild => 'Add a listener';

  @override
  String get createStoryGenerate => 'Create tonight\'s story';

  @override
  String get createStoryGenerating => 'Creating…';

  @override
  String get createStoryConfirmTitle => 'Create tonight\'s story?';

  @override
  String get createStoryConfirmCannotUndo =>
      'This uses 1 story from your monthly quota and can\'t be undone.';

  @override
  String get createStoryConfirmAction => 'Confirm';

  @override
  String get createStoryConfirmCancel => 'Not yet';

  @override
  String get createStoryQuotaPrefix => 'Stories this month ';

  @override
  String createStoryQuotaLine(Object used, Object limit) {
    return 'Stories this month $used/$limit';
  }

  @override
  String get createStoryListenersTitle => 'Who\'s listening tonight?';

  @override
  String get createStoryListenersSubMulti =>
      'You can pick more than one; we\'ll use their preferences';

  @override
  String get createStoryListenersSubSingle =>
      'We\'ll use this listener\'s preferences';

  @override
  String get createStoryManageListeners => 'Manage listeners';

  @override
  String get createStoryPrimaryListener => 'Primary listener';

  @override
  String get createStoryNoPrefer => 'No preferences yet · Soft bedtime tales';

  @override
  String get createStoryOptionsTitle => 'What kind of story?';

  @override
  String get createStoryOptionsSubtitle =>
      'We\'ll build tonight\'s story from these choices';

  @override
  String get createStoryInspiration => 'Idea';

  @override
  String get createStoryThemeModeSeed => 'Theme only';

  @override
  String get createStoryThemeModePlot => 'Write a plot';

  @override
  String createStoryThemeHint(String example) {
    return 'One-line spark (e.g. $example)';
  }

  @override
  String get createStoryThemePlotHint =>
      'Write tonight’s plot — we’ll follow it';

  @override
  String get createStoryCastTitle => 'Tonight\'s cast';

  @override
  String get createStoryAddCharacter => 'Add';

  @override
  String get createStoryCastEmpty =>
      'Add listeners, family, or toys in Characters.';

  @override
  String get createStoryCharacterFallback => 'Character';

  @override
  String get createStoryType => 'Story type';

  @override
  String get createStoryVoice => 'Voice';

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
  String get createStoryMoreOptions => 'More options';

  @override
  String get createStoryLanguage => 'Language';

  @override
  String get createStoryLangZh => 'Chinese';

  @override
  String get createStoryEnglishSoon =>
      'English stories aren\'t available yet. Stay tuned.';

  @override
  String get createStoryDialogue => 'Dialogue';

  @override
  String get createStoryTypeEveryday => 'Everyday';

  @override
  String get createStoryTypeSoft => 'Gentle wonder';

  @override
  String get createStoryTypeFantasy => 'Fantasy';

  @override
  String get createStoryDialogueLow => 'Very little';

  @override
  String get createStoryDialogueSome => 'A little';

  @override
  String get createStoryDialogueMore => 'More';

  @override
  String get createStorySoftSeries => 'Soft series (continuable)';

  @override
  String get createStorySoftHook => 'Previous soft hook (optional)';

  @override
  String get createStoryEpisodeNo => 'Episode number';

  @override
  String get createStoryDreamRules => 'Bedtime pace';

  @override
  String get createStoryDreamRulesBody =>
      'The story eases into a calm rhythm, then fades into soft goodnight sounds.';

  @override
  String get createStoryDuration => 'Length';

  @override
  String get createStoryLengthShort => 'Short';

  @override
  String get createStoryLengthMedium => 'Medium';

  @override
  String get createStoryLengthLong => 'Long';

  @override
  String get createStoryLengthHintShort => 'About 2–4 min';

  @override
  String get createStoryLengthHintMedium => 'About 4–7 min';

  @override
  String get createStoryLengthHintLong => 'About 8–12 min';

  @override
  String get createStoryErrAddChild => 'Please add a listener first';

  @override
  String get createStoryErrNickname =>
      'Please add a nickname (tap the profile to edit)';

  @override
  String get createStoryErrVoice => 'Please choose a voice';

  @override
  String get createStoryErrListener => 'Please choose tonight\'s listener';

  @override
  String get playerTitle => 'Story';

  @override
  String get playerStatusLive => 'Playing';

  @override
  String get playerModePicture => 'Picture book';

  @override
  String get playerModeAudio => 'Audio only';

  @override
  String get playerWarmLight => 'Warm light';

  @override
  String get playerBrandLine => 'Huhu · Pillow Tales';

  @override
  String get playerCoRead => 'Read along';

  @override
  String get playerFullText => 'Full text';

  @override
  String get playerFollowAlong => 'Follow the words';

  @override
  String get playerCollapse => 'Collapse';

  @override
  String get playerExpand => 'Full text';

  @override
  String get playerSpeedTitle => 'Narration speed';

  @override
  String get playerSpeedHint =>
      'Changes story speed only. Background music stays the same — no re-recording.';

  @override
  String playerSpeedCurrent(String speed) {
    return 'Current $speed×';
  }

  @override
  String playerBedTrack(String label) {
    return 'Sleep sounds · $label';
  }

  @override
  String get playerBedMusicBox => 'Music box';

  @override
  String playerRemain(String time) {
    return '$time left';
  }

  @override
  String get playerBedFading => 'Sleep sounds fading out';

  @override
  String get playerOutroOff => 'Stop sleep music when the story ends';

  @override
  String playerOutroMinutes(int minutes) {
    return 'Play $minutes more min after the story';
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
  String get playerTimerTitle => 'Sleep music timer';

  @override
  String get playerTimerSubtitle =>
      'How long music keeps playing after the story';

  @override
  String playerTimerFading(String time) {
    return 'Fading out · $time left';
  }

  @override
  String get playerTimerDelay => 'Delay';

  @override
  String get playerOutroMood0 => '0 min · stop with story';

  @override
  String get playerOutroMood1 => '1 min · soft fade';

  @override
  String get playerOutroMood5 => '5 min · wind-down';

  @override
  String get playerOutroMood10 => '10 min · settle';

  @override
  String get playerOutroMood15 => '15 min · linger';

  @override
  String get playerOutroMood30 => '30 min · stay on';

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
    return '$years yr $months mo';
  }

  @override
  String get commonPleaseSelect => 'Please select';

  @override
  String get storiesContinueEpisodeTooltip => 'Continue next episode';

  @override
  String get netTimeout => 'Network timed out. Please try again.';

  @override
  String get netOfflineCached => 'You\'re offline. Showing saved content.';

  @override
  String get apiSessionExpired => 'Session expired. Please sign in again.';

  @override
  String get apiRefreshFailed => 'Couldn\'t refresh sign-in.';

  @override
  String get apiStoryGenerateFailed => 'Couldn\'t create this story';

  @override
  String get apiStoryCreateFailed => 'Couldn\'t start this story';

  @override
  String get apiStoryWaitNetworkUnstable =>
      'Connection is unstable — creation may still be running. Refresh Stories later, or keep waiting.';

  @override
  String get apiStoryWaitTimeout =>
      'Timed out — creation may still be running. Refresh later or keep waiting.';

  @override
  String get apiStoryWaitOffline =>
      'You\'re offline — creation may still be running. When back online, tap Keep waiting.';

  @override
  String get apiStoryWaitDeadline =>
      'Timed out waiting. Check Stories to see if it finished.';

  @override
  String get apiNetworkUnstableRetry =>
      'Connection is unstable. Please try again.';

  @override
  String get apiForbidden => 'You don\'t have permission for this';

  @override
  String get apiNotFound => 'Not found';

  @override
  String get apiTooManyRequests => 'Too many requests. Please try again later.';

  @override
  String get apiServerUnavailable =>
      'Service is temporarily unavailable. Please try again later.';

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
      'For staging/online, run with --dart-define=APP_ENV=staging\n(see assets/config/staging.json) and register with an invite code or sign in with phone.';

  @override
  String get bootHintLocal =>
      'If the screen stays blank or won\'t connect: Settings → Privacy & Security → Local Network → enable this app;\nfor a physical device set api_base_url in assets/config/dev.local.json (copy from *.example) to http://<your-Mac-LAN-IP>:8000.';
}
