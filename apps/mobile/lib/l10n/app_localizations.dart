import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Huhu · Pillow Tales'**
  String get appTitle;

  /// No description provided for @meTitle.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get meTitle;

  /// No description provided for @tabStories.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get tabStories;

  /// No description provided for @meSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get meSettings;

  /// No description provided for @meVoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Voices'**
  String get meVoicesTitle;

  /// No description provided for @meVoicesSubtitleClone.
  ///
  /// In en, this message translates to:
  /// **'System voices and parent voice clone'**
  String get meVoicesSubtitleClone;

  /// No description provided for @meVoicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'System reading voices'**
  String get meVoicesSubtitle;

  /// No description provided for @meCharactersTitle.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get meCharactersTitle;

  /// No description provided for @meCharactersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Listeners and story cast'**
  String get meCharactersSubtitle;

  /// No description provided for @meLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get meLanguageTitle;

  /// No description provided for @meLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{label}'**
  String meLanguageSubtitle(String label);

  /// No description provided for @meAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get meAboutTitle;

  /// No description provided for @meAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Product and contact'**
  String get meAboutSubtitle;

  /// No description provided for @meTermsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get meTermsTitle;

  /// No description provided for @meTermsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'User agreement'**
  String get meTermsSubtitle;

  /// No description provided for @mePrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get mePrivacyTitle;

  /// No description provided for @mePrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How we handle your data'**
  String get mePrivacySubtitle;

  /// No description provided for @meVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String meVersion(String version);

  /// No description provided for @meLogoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Log out of this account'**
  String get meLogoutAccount;

  /// No description provided for @meBrandFooter.
  ///
  /// In en, this message translates to:
  /// **'Huhu · Pillow Tales  Version v{version}'**
  String meBrandFooter(String version);

  /// No description provided for @languagePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languagePickerTitle;

  /// No description provided for @languageZhHans.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageZhHans;

  /// No description provided for @languageZhHant.
  ///
  /// In en, this message translates to:
  /// **'繁體中文'**
  String get languageZhHant;

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @profileGuest.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get profileGuest;

  /// No description provided for @profileGuestHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync stories and voices'**
  String get profileGuestHint;

  /// No description provided for @profileConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected to bedtime service'**
  String get profileConnected;

  /// No description provided for @profileDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Bedtime parent'**
  String get profileDefaultName;

  /// No description provided for @profileLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get profileLogin;

  /// No description provided for @profileLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get profileLogout;

  /// No description provided for @profileRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get profileRefresh;

  /// No description provided for @quotaStories.
  ///
  /// In en, this message translates to:
  /// **'Stories this month {used}/{limit}'**
  String quotaStories(Object used, Object limit);

  /// No description provided for @quotaCloneSuffix.
  ///
  /// In en, this message translates to:
  /// **' · Clones {used}/{limit}'**
  String quotaCloneSuffix(Object used, Object limit);

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Gentle bedtime stories for little listeners'**
  String get aboutTagline;

  /// No description provided for @aboutVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersionLabel;

  /// No description provided for @aboutDeveloperLabel.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get aboutDeveloperLabel;

  /// No description provided for @aboutDeveloperName.
  ///
  /// In en, this message translates to:
  /// **'Lullvale Studio'**
  String get aboutDeveloperName;

  /// No description provided for @aboutSupportLabel.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get aboutSupportLabel;

  /// No description provided for @aboutWebsiteLabel.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get aboutWebsiteLabel;

  /// No description provided for @aboutTermsLink.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get aboutTermsLink;

  /// No description provided for @aboutPrivacyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get aboutPrivacyLink;

  /// No description provided for @aboutCopyright.
  ///
  /// In en, this message translates to:
  /// **'© {year} Lullvale'**
  String aboutCopyright(int year);

  /// No description provided for @termsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsTitle;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyTitle;

  /// No description provided for @legalOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link.'**
  String get legalOpenFailed;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonConfirm;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get commonUnnamed;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get commonLoading;

  /// No description provided for @genderUnspecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get genderUnspecified;

  /// No description provided for @genderBoy.
  ///
  /// In en, this message translates to:
  /// **'Boy'**
  String get genderBoy;

  /// No description provided for @genderGirl.
  ///
  /// In en, this message translates to:
  /// **'Girl'**
  String get genderGirl;

  /// No description provided for @genderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get genderOther;

  /// No description provided for @homeOfflineSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Offline mode: showing cached content. It will sync when you\'re back online.'**
  String get homeOfflineSnackbar;

  /// No description provided for @authBrandName.
  ///
  /// In en, this message translates to:
  /// **'Huhu'**
  String get authBrandName;

  /// No description provided for @authBrandBadge.
  ///
  /// In en, this message translates to:
  /// **'Pillow Tales'**
  String get authBrandBadge;

  /// No description provided for @authSubtitleLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue your bedtime stories'**
  String get authSubtitleLogin;

  /// No description provided for @authSubtitleRegister.
  ///
  /// In en, this message translates to:
  /// **'Create an account with an invite code'**
  String get authSubtitleRegister;

  /// No description provided for @authInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get authInviteCode;

  /// No description provided for @authNicknameOptional.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get authNicknameOptional;

  /// No description provided for @authPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get authPhone;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authLoginSms.
  ///
  /// In en, this message translates to:
  /// **'Sign in with code'**
  String get authLoginSms;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authSubmitLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSubmitLogin;

  /// No description provided for @authSubmitRegister.
  ///
  /// In en, this message translates to:
  /// **'Register & sign in'**
  String get authSubmitRegister;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authHaveAccount;

  /// No description provided for @authHaveInvite.
  ///
  /// In en, this message translates to:
  /// **'Have an invite code? '**
  String get authHaveInvite;

  /// No description provided for @authGoLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authGoLogin;

  /// No description provided for @authGoRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get authGoRegister;

  /// No description provided for @authNightHint.
  ///
  /// In en, this message translates to:
  /// **'Low blue light for night · Sweet dreams'**
  String get authNightHint;

  /// No description provided for @authAgreeRegisterPrefix.
  ///
  /// In en, this message translates to:
  /// **'By registering, you agree to the '**
  String get authAgreeRegisterPrefix;

  /// No description provided for @authAgreeLoginPrefix.
  ///
  /// In en, this message translates to:
  /// **'By signing in, you agree to the '**
  String get authAgreeLoginPrefix;

  /// No description provided for @authTermsLink.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get authTermsLink;

  /// No description provided for @authAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get authAnd;

  /// No description provided for @authPrivacyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authPrivacyLink;

  /// No description provided for @authPrivacyLinkRegister.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authPrivacyLinkRegister;

  /// No description provided for @authErrorInviteRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter an invite code'**
  String get authErrorInviteRequired;

  /// No description provided for @authErrorPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a phone number'**
  String get authErrorPhoneRequired;

  /// No description provided for @authErrorPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get authErrorPasswordShort;

  /// No description provided for @authErrorPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authErrorPasswordMismatch;

  /// No description provided for @authErrorPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get authErrorPasswordRequired;

  /// No description provided for @authErrorInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'Invalid sign-in response'**
  String get authErrorInvalidResponse;

  /// No description provided for @authComingSoon.
  ///
  /// In en, this message translates to:
  /// **'{feature} is not available yet. Stay tuned.'**
  String authComingSoon(String feature);

  /// No description provided for @authFeatureSmsLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign-in with code'**
  String get authFeatureSmsLogin;

  /// No description provided for @authFeatureRecoverPassword.
  ///
  /// In en, this message translates to:
  /// **'Password recovery'**
  String get authFeatureRecoverPassword;

  /// No description provided for @storyProgressQueued.
  ///
  /// In en, this message translates to:
  /// **'In queue…'**
  String get storyProgressQueued;

  /// No description provided for @storyProgressSeriesOutline.
  ///
  /// In en, this message translates to:
  /// **'Outlining the series…'**
  String get storyProgressSeriesOutline;

  /// No description provided for @storyProgressEpisodePlan.
  ///
  /// In en, this message translates to:
  /// **'Planning tonight\'s plot…'**
  String get storyProgressEpisodePlan;

  /// No description provided for @storyProgressDraft.
  ///
  /// In en, this message translates to:
  /// **'Writing the story…'**
  String get storyProgressDraft;

  /// No description provided for @storyProgressTts.
  ///
  /// In en, this message translates to:
  /// **'Generating narration audio…'**
  String get storyProgressTts;

  /// No description provided for @storyProgressReady.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get storyProgressReady;

  /// No description provided for @storyProgressReadyPlay.
  ///
  /// In en, this message translates to:
  /// **'Done — ready to play…'**
  String get storyProgressReadyPlay;

  /// No description provided for @storyProgressFailed.
  ///
  /// In en, this message translates to:
  /// **'Generation failed'**
  String get storyProgressFailed;

  /// No description provided for @storyProgressGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating ({progress})…'**
  String storyProgressGenerating(String progress);

  /// No description provided for @storyGenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'Story generation failed'**
  String get storyGenerateFailed;

  /// No description provided for @storyGenerateFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Story generation failed. You can retry.'**
  String get storyGenerateFailedRetry;

  /// No description provided for @storyStillGenerating.
  ///
  /// In en, this message translates to:
  /// **'Still generating — pull to refresh, then listen'**
  String get storyStillGenerating;

  /// No description provided for @storyNoAudio.
  ///
  /// In en, this message translates to:
  /// **'No audio available to play'**
  String get storyNoAudio;

  /// No description provided for @storyNoAudioShort.
  ///
  /// In en, this message translates to:
  /// **'No audio yet'**
  String get storyNoAudioShort;

  /// No description provided for @storyCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create story'**
  String get storyCreateFailed;

  /// No description provided for @storyRetrying.
  ///
  /// In en, this message translates to:
  /// **'Regenerating…'**
  String get storyRetrying;

  /// No description provided for @storyResumeWaiting.
  ///
  /// In en, this message translates to:
  /// **'Still waiting for generation…'**
  String get storyResumeWaiting;

  /// No description provided for @storyContinueWaiting.
  ///
  /// In en, this message translates to:
  /// **'Keep waiting'**
  String get storyContinueWaiting;

  /// No description provided for @storyContinuingEpisode.
  ///
  /// In en, this message translates to:
  /// **'Writing the next episode…'**
  String get storyContinuingEpisode;

  /// No description provided for @storySubmittedQueued.
  ///
  /// In en, this message translates to:
  /// **'Submitted — in queue…'**
  String get storySubmittedQueued;

  /// No description provided for @storiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get storiesTitle;

  /// No description provided for @storiesStatusWaitingFirst.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the first one'**
  String get storiesStatusWaitingFirst;

  /// No description provided for @storiesStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Night light ready'**
  String get storiesStatusReady;

  /// No description provided for @storiesCreateEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Dream engine · New chapter'**
  String get storiesCreateEyebrow;

  /// No description provided for @storiesCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create tonight\'s story'**
  String get storiesCreateTitle;

  /// No description provided for @storiesCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Custom cast, plot, and soothing audio'**
  String get storiesCreateSubtitle;

  /// No description provided for @storiesLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Pillow tale bookshelf'**
  String get storiesLibraryTitle;

  /// No description provided for @storiesLibraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stories yet'**
  String get storiesLibraryEmpty;

  /// No description provided for @storiesLibraryCount.
  ///
  /// In en, this message translates to:
  /// **'Newest first · {count} stories'**
  String storiesLibraryCount(int count);

  /// No description provided for @storiesEmptyShelfTitle.
  ///
  /// In en, this message translates to:
  /// **'An empty shelf'**
  String get storiesEmptyShelfTitle;

  /// No description provided for @storiesEmptyShelfBody.
  ///
  /// In en, this message translates to:
  /// **'Tonight\'s first little book is waiting — tap the golden card above.'**
  String get storiesEmptyShelfBody;

  /// No description provided for @storiesUntitled.
  ///
  /// In en, this message translates to:
  /// **'Unfinished story'**
  String get storiesUntitled;

  /// No description provided for @storiesFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Generation failed · Retry available'**
  String get storiesFailedRetry;

  /// No description provided for @storiesFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Failed · {error}'**
  String storiesFailedWithError(String error);

  /// No description provided for @storiesSeriesContinueHint.
  ///
  /// In en, this message translates to:
  /// **'To continue a series, start again from Create'**
  String get storiesSeriesContinueHint;

  /// No description provided for @storiesMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String storiesMinutes(Object minutes);

  /// No description provided for @storiesSeriesMeta.
  ///
  /// In en, this message translates to:
  /// **'Series #{id}'**
  String storiesSeriesMeta(Object id);

  /// No description provided for @storiesEpisodeMeta.
  ///
  /// In en, this message translates to:
  /// **' Ep. {ep}'**
  String storiesEpisodeMeta(Object ep);

  /// No description provided for @creatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Creating'**
  String get creatingTitle;

  /// No description provided for @creatingBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back to stories'**
  String get creatingBackTooltip;

  /// No description provided for @creatingHeadlineOk.
  ///
  /// In en, this message translates to:
  /// **'Writing tonight\'s story'**
  String get creatingHeadlineOk;

  /// No description provided for @creatingHeadlineFail.
  ///
  /// In en, this message translates to:
  /// **'This one didn\'t finish'**
  String get creatingHeadlineFail;

  /// No description provided for @creatingBodyOk.
  ///
  /// In en, this message translates to:
  /// **'The cloud is writing the text and recording narration — usually a minute or two.'**
  String get creatingBodyOk;

  /// No description provided for @creatingBodyFail.
  ///
  /// In en, this message translates to:
  /// **'You can retry, or go back to the list and open this story later.'**
  String get creatingBodyFail;

  /// No description provided for @creatingHintsOkTitle.
  ///
  /// In en, this message translates to:
  /// **'While it generates'**
  String get creatingHintsOkTitle;

  /// No description provided for @creatingHintsFailTitle.
  ///
  /// In en, this message translates to:
  /// **'What you can do next'**
  String get creatingHintsFailTitle;

  /// No description provided for @creatingHintAutoPlay.
  ///
  /// In en, this message translates to:
  /// **'When it\'s done, you\'ll open the player and start listening automatically.'**
  String get creatingHintAutoPlay;

  /// No description provided for @creatingHintCloud.
  ///
  /// In en, this message translates to:
  /// **'Creation continues in the cloud — closing this page is fine.'**
  String get creatingHintCloud;

  /// No description provided for @creatingHintList.
  ///
  /// In en, this message translates to:
  /// **'Return to Stories anytime to check progress or listen later.'**
  String get creatingHintList;

  /// No description provided for @creatingHintRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap retry below to continue this story without using extra quota.'**
  String get creatingHintRetry;

  /// No description provided for @creatingHintBackLater.
  ///
  /// In en, this message translates to:
  /// **'Or go back to the list and open or retry later.'**
  String get creatingHintBackLater;

  /// No description provided for @creatingRetry.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get creatingRetry;

  /// No description provided for @creatingRetrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying…'**
  String get creatingRetrying;

  /// No description provided for @creatingBackFailed.
  ///
  /// In en, this message translates to:
  /// **'Back to stories'**
  String get creatingBackFailed;

  /// No description provided for @creatingBackOk.
  ///
  /// In en, this message translates to:
  /// **'Back to stories for now'**
  String get creatingBackOk;

  /// No description provided for @voicesManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Voices'**
  String get voicesManageTitle;

  /// No description provided for @voicesManageEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Huhu · Voice'**
  String get voicesManageEyebrow;

  /// No description provided for @voicesManageHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'My voices'**
  String get voicesManageHeaderTitle;

  /// No description provided for @voicesManageSubtitleClone.
  ///
  /// In en, this message translates to:
  /// **'Manage narration voices, or clone a parent\'s voice for bedtime stories'**
  String get voicesManageSubtitleClone;

  /// No description provided for @voicesManageSubtitleSystem.
  ///
  /// In en, this message translates to:
  /// **'Manage system narration voices — preview and pick one'**
  String get voicesManageSubtitleSystem;

  /// No description provided for @voicesManageCloneCta.
  ///
  /// In en, this message translates to:
  /// **'Clone a new voice'**
  String get voicesManageCloneCta;

  /// No description provided for @voicesManageSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved voices'**
  String get voicesManageSectionTitle;

  /// No description provided for @voicesManageNone.
  ///
  /// In en, this message translates to:
  /// **'No voices yet'**
  String get voicesManageNone;

  /// No description provided for @voicesManageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} voices · Preview available'**
  String voicesManageCount(int count);

  /// No description provided for @voicesManageEmptyCloneHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the button above to clone a parent\'s voice.'**
  String get voicesManageEmptyCloneHint;

  /// No description provided for @voicesManageEmptySystemHint.
  ///
  /// In en, this message translates to:
  /// **'No system voices available. Try again later or contact support.'**
  String get voicesManageEmptySystemHint;

  /// No description provided for @voicesKindClone.
  ///
  /// In en, this message translates to:
  /// **'Cloned voice'**
  String get voicesKindClone;

  /// No description provided for @voicesKindSystem.
  ///
  /// In en, this message translates to:
  /// **'System voice'**
  String get voicesKindSystem;

  /// No description provided for @voicesPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No preview'**
  String get voicesPreviewUnavailable;

  /// No description provided for @voicesPreviewUnavailableSnack.
  ///
  /// In en, this message translates to:
  /// **'Preview isn\'t available for this voice yet. Try again later.'**
  String get voicesPreviewUnavailableSnack;

  /// No description provided for @voicesPreviewUnavailableShort.
  ///
  /// In en, this message translates to:
  /// **'No preview for this voice'**
  String get voicesPreviewUnavailableShort;

  /// No description provided for @voicesPreviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play preview'**
  String get voicesPreviewFailed;

  /// No description provided for @voicesPreviewPlay.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get voicesPreviewPlay;

  /// No description provided for @voicesPreviewStop.
  ///
  /// In en, this message translates to:
  /// **'Stop preview'**
  String get voicesPreviewStop;

  /// No description provided for @voicesPreviewStopShort.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get voicesPreviewStopShort;

  /// No description provided for @voicesNoPreviewSuffix.
  ///
  /// In en, this message translates to:
  /// **' · No preview'**
  String get voicesNoPreviewSuffix;

  /// No description provided for @voiceCloneTitle.
  ///
  /// In en, this message translates to:
  /// **'Clone a new voice'**
  String get voiceCloneTitle;

  /// No description provided for @voiceCloneEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Huhu · Clone'**
  String get voiceCloneEyebrow;

  /// No description provided for @voiceCloneHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Record a parent\'s voice'**
  String get voiceCloneHeaderTitle;

  /// No description provided for @voiceCloneHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'In a quiet place, read for about 10–15 seconds. The clone can narrate bedtime stories.'**
  String get voiceCloneHeaderSubtitle;

  /// No description provided for @voiceCloneNameSection.
  ///
  /// In en, this message translates to:
  /// **'Voice name'**
  String get voiceCloneNameSection;

  /// No description provided for @voiceCloneNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Mom\'s voice, Dad\'s bedtime voice'**
  String get voiceCloneNameHint;

  /// No description provided for @voiceCloneDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Parent voice'**
  String get voiceCloneDefaultName;

  /// No description provided for @voiceCloneUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get voiceCloneUsageTitle;

  /// No description provided for @voiceCloneUsageBody.
  ///
  /// In en, this message translates to:
  /// **'Original recordings are deleted soon after upload. Once cloned, you can pick this voice when creating stories.'**
  String get voiceCloneUsageBody;

  /// No description provided for @voiceCloneConsent.
  ///
  /// In en, this message translates to:
  /// **'I agree to use my voice for bedtime story narration in this app'**
  String get voiceCloneConsent;

  /// No description provided for @voiceCloneScriptTitle.
  ///
  /// In en, this message translates to:
  /// **'Please read this aloud'**
  String get voiceCloneScriptTitle;

  /// No description provided for @voiceCloneScriptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You may read both Chinese and English once; a natural pace is fine'**
  String get voiceCloneScriptSubtitle;

  /// No description provided for @voiceCloneScriptZh.
  ///
  /// In en, this message translates to:
  /// **'Tonight I\'ll tell a gentle bedtime story in a soft voice. The wind is light, the moon is bright, and we slowly close our eyes.'**
  String get voiceCloneScriptZh;

  /// No description provided for @voiceCloneStartRecord.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get voiceCloneStartRecord;

  /// No description provided for @voiceCloneStopRecord.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get voiceCloneStopRecord;

  /// No description provided for @voiceCloneRerecord.
  ///
  /// In en, this message translates to:
  /// **'Record again'**
  String get voiceCloneRerecord;

  /// No description provided for @voiceCloneRecordingHint.
  ///
  /// In en, this message translates to:
  /// **'Recording… tap stop when you\'re done'**
  String get voiceCloneRecordingHint;

  /// No description provided for @voiceCloneReadyHint.
  ///
  /// In en, this message translates to:
  /// **'Sample ready — confirm the name and consent, then upload to clone'**
  String get voiceCloneReadyHint;

  /// No description provided for @voiceCloneUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload & clone'**
  String get voiceCloneUpload;

  /// No description provided for @voiceCloneUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get voiceCloneUploading;

  /// No description provided for @voiceCloneNeedMic.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required'**
  String get voiceCloneNeedMic;

  /// No description provided for @voiceCloneNeedName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a voice name'**
  String get voiceCloneNeedName;

  /// No description provided for @voiceCloneNeedConsent.
  ///
  /// In en, this message translates to:
  /// **'Please accept the consent checkbox'**
  String get voiceCloneNeedConsent;

  /// No description provided for @voiceCloneSuccess.
  ///
  /// In en, this message translates to:
  /// **'Clone ready — you can use it when creating stories'**
  String get voiceCloneSuccess;

  /// No description provided for @voicePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a voice'**
  String get voicePickerTitle;

  /// No description provided for @voicePickerHint.
  ///
  /// In en, this message translates to:
  /// **'Preview, then confirm to use'**
  String get voicePickerHint;

  /// No description provided for @voicePickerUse.
  ///
  /// In en, this message translates to:
  /// **'Use this voice'**
  String get voicePickerUse;

  /// No description provided for @voicePickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get voicePickerEmpty;

  /// No description provided for @voicePickerUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed voice'**
  String get voicePickerUnnamed;

  /// No description provided for @childrenManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get childrenManageTitle;

  /// No description provided for @childrenManageTagline.
  ///
  /// In en, this message translates to:
  /// **'Dream cast book · Tailored bedtime tales'**
  String get childrenManageTagline;

  /// No description provided for @childrenTabListeners.
  ///
  /// In en, this message translates to:
  /// **'Listeners'**
  String get childrenTabListeners;

  /// No description provided for @childrenTabPeople.
  ///
  /// In en, this message translates to:
  /// **'Family & friends'**
  String get childrenTabPeople;

  /// No description provided for @childrenTabToys.
  ///
  /// In en, this message translates to:
  /// **'Toy pals'**
  String get childrenTabToys;

  /// No description provided for @childrenFabListener.
  ///
  /// In en, this message translates to:
  /// **'Add a listener'**
  String get childrenFabListener;

  /// No description provided for @childrenFabPeople.
  ///
  /// In en, this message translates to:
  /// **'Add family or friend'**
  String get childrenFabPeople;

  /// No description provided for @childrenFabToy.
  ///
  /// In en, this message translates to:
  /// **'Add a toy pal'**
  String get childrenFabToy;

  /// No description provided for @childrenEmptyListenersTitle.
  ///
  /// In en, this message translates to:
  /// **'No listeners yet'**
  String get childrenEmptyListenersTitle;

  /// No description provided for @childrenEmptyListenersBody.
  ///
  /// In en, this message translates to:
  /// **'Add a listener profile first to create stories and attach family or toys.'**
  String get childrenEmptyListenersBody;

  /// No description provided for @childrenEmptyListenersCta.
  ///
  /// In en, this message translates to:
  /// **'Add your first listener'**
  String get childrenEmptyListenersCta;

  /// No description provided for @childrenEmptyPeopleTitle.
  ///
  /// In en, this message translates to:
  /// **'No family or friends yet'**
  String get childrenEmptyPeopleTitle;

  /// No description provided for @childrenEmptyPeopleBody.
  ///
  /// In en, this message translates to:
  /// **'Add grandparents, classmates, and more so they can appear in stories.'**
  String get childrenEmptyPeopleBody;

  /// No description provided for @childrenEmptyToysTitle.
  ///
  /// In en, this message translates to:
  /// **'No toy pals yet'**
  String get childrenEmptyToysTitle;

  /// No description provided for @childrenEmptyToysBody.
  ///
  /// In en, this message translates to:
  /// **'Add dolls and plush friends so they can appear in stories.'**
  String get childrenEmptyToysBody;

  /// No description provided for @childrenNeedListenerFirst.
  ///
  /// In en, this message translates to:
  /// **'Please add a listener first'**
  String get childrenNeedListenerFirst;

  /// No description provided for @childrenSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Listener profile'**
  String get childrenSheetTitle;

  /// No description provided for @childrenNickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get childrenNickname;

  /// No description provided for @childrenGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get childrenGender;

  /// No description provided for @childrenBirthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get childrenBirthday;

  /// No description provided for @childrenPickBirthday.
  ///
  /// In en, this message translates to:
  /// **'Choose birthday'**
  String get childrenPickBirthday;

  /// No description provided for @childrenBirthdayHint.
  ///
  /// In en, this message translates to:
  /// **'YYYY/MM/DD'**
  String get childrenBirthdayHint;

  /// No description provided for @childrenIntroOptional.
  ///
  /// In en, this message translates to:
  /// **'Bio (optional)'**
  String get childrenIntroOptional;

  /// No description provided for @childrenIntroHint.
  ///
  /// In en, this message translates to:
  /// **'Personality, recent mood…'**
  String get childrenIntroHint;

  /// No description provided for @childrenPreferLabel.
  ///
  /// In en, this message translates to:
  /// **'Story preferences (comma-separated)'**
  String get childrenPreferLabel;

  /// No description provided for @childrenPreferHint.
  ///
  /// In en, this message translates to:
  /// **'Dinosaur adventures, gentle fairy tales, a touch of humor'**
  String get childrenPreferHint;

  /// No description provided for @childrenAddToy.
  ///
  /// In en, this message translates to:
  /// **'Add toy'**
  String get childrenAddToy;

  /// No description provided for @childrenEditToy.
  ///
  /// In en, this message translates to:
  /// **'Edit toy'**
  String get childrenEditToy;

  /// No description provided for @childrenAddPerson.
  ///
  /// In en, this message translates to:
  /// **'Add family / friend'**
  String get childrenAddPerson;

  /// No description provided for @childrenEditPerson.
  ///
  /// In en, this message translates to:
  /// **'Edit family / friend'**
  String get childrenEditPerson;

  /// No description provided for @childrenToyName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get childrenToyName;

  /// No description provided for @childrenPersonName.
  ///
  /// In en, this message translates to:
  /// **'Name / title'**
  String get childrenPersonName;

  /// No description provided for @childrenToyNameHint.
  ///
  /// In en, this message translates to:
  /// **'Star doll'**
  String get childrenToyNameHint;

  /// No description provided for @childrenPersonNameHint.
  ///
  /// In en, this message translates to:
  /// **'Grandpa'**
  String get childrenPersonNameHint;

  /// No description provided for @childrenBelongsTo.
  ///
  /// In en, this message translates to:
  /// **'Belongs to'**
  String get childrenBelongsTo;

  /// No description provided for @childrenLinkedListener.
  ///
  /// In en, this message translates to:
  /// **'Linked listener'**
  String get childrenLinkedListener;

  /// No description provided for @childrenRelation.
  ///
  /// In en, this message translates to:
  /// **'Relation'**
  String get childrenRelation;

  /// No description provided for @childrenRelationHint.
  ///
  /// In en, this message translates to:
  /// **'Grandpa / classmate / teacher…'**
  String get childrenRelationHint;

  /// No description provided for @childrenToyNote.
  ///
  /// In en, this message translates to:
  /// **'Look / temperament (optional)'**
  String get childrenToyNote;

  /// No description provided for @childrenPersonNote.
  ///
  /// In en, this message translates to:
  /// **'Traits (optional)'**
  String get childrenPersonNote;

  /// No description provided for @childrenToyNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Blue ears, loves to sing'**
  String get childrenToyNoteHint;

  /// No description provided for @childrenPersonNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Loves telling stories'**
  String get childrenPersonNoteHint;

  /// No description provided for @childrenDeleteListenerTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this listener?'**
  String get childrenDeleteListenerTitle;

  /// No description provided for @childrenDeleteListenerBody.
  ///
  /// In en, this message translates to:
  /// **'This will also delete family and toy characters under “{name}”.'**
  String childrenDeleteListenerBody(String name);

  /// No description provided for @childrenDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted “{name}”'**
  String childrenDeleted(String name);

  /// No description provided for @childrenDeleteCharacterTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this character?'**
  String get childrenDeleteCharacterTitle;

  /// No description provided for @childrenDeleteCharacterBody.
  ///
  /// In en, this message translates to:
  /// **'After deleting “{name}”, you won\'t be able to select them when creating stories.'**
  String childrenDeleteCharacterBody(String name);

  /// No description provided for @childrenDefaultCharacter.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get childrenDefaultCharacter;

  /// No description provided for @childrenTagListener.
  ///
  /// In en, this message translates to:
  /// **'Listener'**
  String get childrenTagListener;

  /// No description provided for @childrenTagToy.
  ///
  /// In en, this message translates to:
  /// **'Comfort plush'**
  String get childrenTagToy;

  /// No description provided for @childrenTagPeople.
  ///
  /// In en, this message translates to:
  /// **'Family & friends'**
  String get childrenTagPeople;

  /// No description provided for @childrenPreferPrefix.
  ///
  /// In en, this message translates to:
  /// **'Likes: {prefs}'**
  String childrenPreferPrefix(String prefs);

  /// No description provided for @childrenEditPrefs.
  ///
  /// In en, this message translates to:
  /// **'Edit profile & bedtime prefs'**
  String get childrenEditPrefs;

  /// No description provided for @childrenSleepPreset.
  ///
  /// In en, this message translates to:
  /// **'Sleep preset'**
  String get childrenSleepPreset;

  /// No description provided for @childrenBelongsToName.
  ///
  /// In en, this message translates to:
  /// **'Belongs to {name}'**
  String childrenBelongsToName(String name);

  /// No description provided for @childrenToySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bedside pal · Belongs to {name}'**
  String childrenToySubtitle(String name);

  /// No description provided for @childrenPersonalityPrefix.
  ///
  /// In en, this message translates to:
  /// **'Personality: {note}'**
  String childrenPersonalityPrefix(String note);

  /// No description provided for @childrenUnlinked.
  ///
  /// In en, this message translates to:
  /// **'Unlinked'**
  String get childrenUnlinked;

  /// No description provided for @childrenChildFallback.
  ///
  /// In en, this message translates to:
  /// **'Child #{id}'**
  String childrenChildFallback(int id);

  /// No description provided for @childrenMagicTitle.
  ///
  /// In en, this message translates to:
  /// **'Character magic'**
  String get childrenMagicTitle;

  /// No description provided for @childrenMagicBody.
  ///
  /// In en, this message translates to:
  /// **'The dream engine uses the lead\'s age and preferences to weave gentle lines and a soothing bedtime rhythm into each night\'s soundscape.'**
  String get childrenMagicBody;

  /// No description provided for @createStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Customize tonight\'s story'**
  String get createStoryTitle;

  /// No description provided for @createStoryNeedListenerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a listener first'**
  String get createStoryNeedListenerTitle;

  /// No description provided for @createStoryNeedListenerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'With a child profile, you can customize tonight\'s story'**
  String get createStoryNeedListenerSubtitle;

  /// No description provided for @createStoryNoRolesTitle.
  ///
  /// In en, this message translates to:
  /// **'No characters yet'**
  String get createStoryNoRolesTitle;

  /// No description provided for @createStoryNoRolesBody.
  ///
  /// In en, this message translates to:
  /// **'Create a child profile (nickname, age, and more). Then come back to generate a story.'**
  String get createStoryNoRolesBody;

  /// No description provided for @createStoryGoAddChild.
  ///
  /// In en, this message translates to:
  /// **'Add a child profile'**
  String get createStoryGoAddChild;

  /// No description provided for @createStoryGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate tonight\'s story'**
  String get createStoryGenerate;

  /// No description provided for @createStoryGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get createStoryGenerating;

  /// No description provided for @createStoryQuotaPrefix.
  ///
  /// In en, this message translates to:
  /// **'Stories this month '**
  String get createStoryQuotaPrefix;

  /// No description provided for @createStoryQuotaLine.
  ///
  /// In en, this message translates to:
  /// **'Stories this month {used}/{limit}'**
  String createStoryQuotaLine(Object used, Object limit);

  /// No description provided for @createStoryListenersTitle.
  ///
  /// In en, this message translates to:
  /// **'Who is listening tonight?'**
  String get createStoryListenersTitle;

  /// No description provided for @createStoryListenersSubMulti.
  ///
  /// In en, this message translates to:
  /// **'Multi-select allowed; the story weaves from listeners\' preferences'**
  String get createStoryListenersSubMulti;

  /// No description provided for @createStoryListenersSubSingle.
  ///
  /// In en, this message translates to:
  /// **'The story weaves from the listener\'s preferences'**
  String get createStoryListenersSubSingle;

  /// No description provided for @createStoryManageListeners.
  ///
  /// In en, this message translates to:
  /// **'Manage listener profiles'**
  String get createStoryManageListeners;

  /// No description provided for @createStoryPrimaryListener.
  ///
  /// In en, this message translates to:
  /// **'Primary listener'**
  String get createStoryPrimaryListener;

  /// No description provided for @createStoryNoPrefer.
  ///
  /// In en, this message translates to:
  /// **'No preferences yet · Soft bedtime fairy tales'**
  String get createStoryNoPrefer;

  /// No description provided for @createStoryOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'What story tonight?'**
  String get createStoryOptionsTitle;

  /// No description provided for @createStoryOptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll create from these ingredients'**
  String get createStoryOptionsSubtitle;

  /// No description provided for @createStoryInspiration.
  ///
  /// In en, this message translates to:
  /// **'Story spark'**
  String get createStoryInspiration;

  /// No description provided for @createStoryInspirationHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — you can leave this blank'**
  String get createStoryInspirationHint;

  /// No description provided for @createStoryThemeHint.
  ///
  /// In en, this message translates to:
  /// **'What to tell tonight (optional), e.g. a kitten watching stars on a cloud…'**
  String get createStoryThemeHint;

  /// No description provided for @createStoryCastTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearing tonight'**
  String get createStoryCastTitle;

  /// No description provided for @createStoryAddCharacter.
  ///
  /// In en, this message translates to:
  /// **'Add character'**
  String get createStoryAddCharacter;

  /// No description provided for @createStoryCastEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add listeners, family, or toys in Characters.'**
  String get createStoryCastEmpty;

  /// No description provided for @createStoryCharacterFallback.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get createStoryCharacterFallback;

  /// No description provided for @createStoryType.
  ///
  /// In en, this message translates to:
  /// **'Story type'**
  String get createStoryType;

  /// No description provided for @createStoryVoice.
  ///
  /// In en, this message translates to:
  /// **'Narration voice'**
  String get createStoryVoice;

  /// No description provided for @createStoryVoiceSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected: {name}'**
  String createStoryVoiceSelected(String name);

  /// No description provided for @createStoryVoiceNone.
  ///
  /// In en, this message translates to:
  /// **'No voice selected'**
  String get createStoryVoiceNone;

  /// No description provided for @createStoryVoicePick.
  ///
  /// In en, this message translates to:
  /// **'Choose a voice'**
  String get createStoryVoicePick;

  /// No description provided for @createStoryVoiceChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get createStoryVoiceChange;

  /// No description provided for @createStoryMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options (language & dialogue)'**
  String get createStoryMoreOptions;

  /// No description provided for @createStoryLanguage.
  ///
  /// In en, this message translates to:
  /// **'Narration language'**
  String get createStoryLanguage;

  /// No description provided for @createStoryLangZh.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get createStoryLangZh;

  /// No description provided for @createStoryEnglishSoon.
  ///
  /// In en, this message translates to:
  /// **'English stories aren\'t available yet. Stay tuned.'**
  String get createStoryEnglishSoon;

  /// No description provided for @createStoryDialogue.
  ///
  /// In en, this message translates to:
  /// **'How much dialogue'**
  String get createStoryDialogue;

  /// No description provided for @createStoryTypeEveryday.
  ///
  /// In en, this message translates to:
  /// **'Everyday life'**
  String get createStoryTypeEveryday;

  /// No description provided for @createStoryTypeSoft.
  ///
  /// In en, this message translates to:
  /// **'A touch of imagination'**
  String get createStoryTypeSoft;

  /// No description provided for @createStoryTypeFantasy.
  ///
  /// In en, this message translates to:
  /// **'Wonderful worlds'**
  String get createStoryTypeFantasy;

  /// No description provided for @createStoryDialogueLow.
  ///
  /// In en, this message translates to:
  /// **'Very little dialogue'**
  String get createStoryDialogueLow;

  /// No description provided for @createStoryDialogueSome.
  ///
  /// In en, this message translates to:
  /// **'A little dialogue'**
  String get createStoryDialogueSome;

  /// No description provided for @createStoryDialogueMore.
  ///
  /// In en, this message translates to:
  /// **'More dialogue'**
  String get createStoryDialogueMore;

  /// No description provided for @createStorySoftSeries.
  ///
  /// In en, this message translates to:
  /// **'Soft series (continuable)'**
  String get createStorySoftSeries;

  /// No description provided for @createStorySoftHook.
  ///
  /// In en, this message translates to:
  /// **'Previous soft hook (optional)'**
  String get createStorySoftHook;

  /// No description provided for @createStoryEpisodeNo.
  ///
  /// In en, this message translates to:
  /// **'Episode number'**
  String get createStoryEpisodeNo;

  /// No description provided for @createStoryDreamRules.
  ///
  /// In en, this message translates to:
  /// **'Dream rules'**
  String get createStoryDreamRules;

  /// No description provided for @createStoryDreamRulesBody.
  ///
  /// In en, this message translates to:
  /// **'The story gently settles into a calm rhythm, then fades into goodnight white noise.'**
  String get createStoryDreamRulesBody;

  /// No description provided for @createStoryDuration.
  ///
  /// In en, this message translates to:
  /// **'Length (minutes)'**
  String get createStoryDuration;

  /// No description provided for @createStoryErrAddChild.
  ///
  /// In en, this message translates to:
  /// **'Please add a child profile first'**
  String get createStoryErrAddChild;

  /// No description provided for @createStoryErrNickname.
  ///
  /// In en, this message translates to:
  /// **'Please finish the child\'s nickname (tap the profile card to edit)'**
  String get createStoryErrNickname;

  /// No description provided for @createStoryErrVoice.
  ///
  /// In en, this message translates to:
  /// **'Please choose a voice (or create a system voice on the Voices page)'**
  String get createStoryErrVoice;

  /// No description provided for @createStoryErrListener.
  ///
  /// In en, this message translates to:
  /// **'Please choose tonight\'s listener first'**
  String get createStoryErrListener;

  /// No description provided for @playerTitle.
  ///
  /// In en, this message translates to:
  /// **'Co-read'**
  String get playerTitle;

  /// No description provided for @playerStatusLive.
  ///
  /// In en, this message translates to:
  /// **'Bedside lamp · Night play on'**
  String get playerStatusLive;

  /// No description provided for @playerModePicture.
  ///
  /// In en, this message translates to:
  /// **'Picture book'**
  String get playerModePicture;

  /// No description provided for @playerModeAudio.
  ///
  /// In en, this message translates to:
  /// **'Listen only'**
  String get playerModeAudio;

  /// No description provided for @playerWarmLight.
  ///
  /// In en, this message translates to:
  /// **'Pillow glow'**
  String get playerWarmLight;

  /// No description provided for @playerBrandLine.
  ///
  /// In en, this message translates to:
  /// **'Huhu · Pillow Tales'**
  String get playerBrandLine;

  /// No description provided for @playerCoRead.
  ///
  /// In en, this message translates to:
  /// **'Parent–child co-reading'**
  String get playerCoRead;

  /// No description provided for @playerFullText.
  ///
  /// In en, this message translates to:
  /// **'Full text'**
  String get playerFullText;

  /// No description provided for @playerFollowAlong.
  ///
  /// In en, this message translates to:
  /// **'Words glide along'**
  String get playerFollowAlong;

  /// No description provided for @playerCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get playerCollapse;

  /// No description provided for @playerExpand.
  ///
  /// In en, this message translates to:
  /// **'View full text'**
  String get playerExpand;

  /// No description provided for @playerSpeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Narration speed'**
  String get playerSpeedTitle;

  /// No description provided for @playerSpeedHint.
  ///
  /// In en, this message translates to:
  /// **'Changes story narration only. Background music is unchanged. Audio is not re-synthesized.'**
  String get playerSpeedHint;

  /// No description provided for @playerSpeedCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current {speed}×'**
  String playerSpeedCurrent(String speed);

  /// No description provided for @playerBedTrack.
  ///
  /// In en, this message translates to:
  /// **'Cradle bed sound · {label}'**
  String playerBedTrack(String label);

  /// No description provided for @playerBedMusicBox.
  ///
  /// In en, this message translates to:
  /// **'Music box'**
  String get playerBedMusicBox;

  /// No description provided for @playerRemain.
  ///
  /// In en, this message translates to:
  /// **'Left {time}'**
  String playerRemain(String time);

  /// No description provided for @playerBedFading.
  ///
  /// In en, this message translates to:
  /// **'Bed sound is fading out'**
  String get playerBedFading;

  /// No description provided for @playerOutroOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off sleep music when the story ends'**
  String get playerOutroOff;

  /// No description provided for @playerOutroMinutes.
  ///
  /// In en, this message translates to:
  /// **'Play {minutes} more minutes after the story'**
  String playerOutroMinutes(int minutes);

  /// No description provided for @playerOutroOffShort.
  ///
  /// In en, this message translates to:
  /// **'Off now'**
  String get playerOutroOffShort;

  /// No description provided for @playerOutroMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String playerOutroMinutesShort(int minutes);

  /// No description provided for @playerBedOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get playerBedOff;

  /// No description provided for @playerScript.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get playerScript;

  /// No description provided for @playerTimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Timer for music'**
  String get playerTimerTitle;

  /// No description provided for @playerTimerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delay turning off sleep music after the story ends'**
  String get playerTimerSubtitle;

  /// No description provided for @playerTimerFading.
  ///
  /// In en, this message translates to:
  /// **'Sleep music fading · {time} left'**
  String playerTimerFading(String time);

  /// No description provided for @playerTimerDelay.
  ///
  /// In en, this message translates to:
  /// **'Delay'**
  String get playerTimerDelay;

  /// No description provided for @createStoryDurationMood3.
  ///
  /// In en, this message translates to:
  /// **'3 min · short nap'**
  String get createStoryDurationMood3;

  /// No description provided for @createStoryDurationMood5.
  ///
  /// In en, this message translates to:
  /// **'5 min · ready for sleep'**
  String get createStoryDurationMood5;

  /// No description provided for @createStoryDurationMood8.
  ///
  /// In en, this message translates to:
  /// **'8 min · warm immersion'**
  String get createStoryDurationMood8;

  /// No description provided for @createStoryDurationMood10.
  ///
  /// In en, this message translates to:
  /// **'10 min · long fairy tale'**
  String get createStoryDurationMood10;

  /// No description provided for @createStoryDurationMood12.
  ///
  /// In en, this message translates to:
  /// **'12 min · deep rest'**
  String get createStoryDurationMood12;

  /// No description provided for @createStoryDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String createStoryDurationMinutes(int minutes);

  /// No description provided for @playerOutroMood0.
  ///
  /// In en, this message translates to:
  /// **'0 min · stop when story ends'**
  String get playerOutroMood0;

  /// No description provided for @playerOutroMood1.
  ///
  /// In en, this message translates to:
  /// **'1 min · soft afterglow'**
  String get playerOutroMood1;

  /// No description provided for @playerOutroMood5.
  ///
  /// In en, this message translates to:
  /// **'5 min · gentle wind-down'**
  String get playerOutroMood5;

  /// No description provided for @playerOutroMood10.
  ///
  /// In en, this message translates to:
  /// **'10 min · slowly quiet'**
  String get playerOutroMood10;

  /// No description provided for @playerOutroMood15.
  ///
  /// In en, this message translates to:
  /// **'15 min · sleep echoes'**
  String get playerOutroMood15;

  /// No description provided for @playerOutroMood30.
  ///
  /// In en, this message translates to:
  /// **'30 min · all-night companion'**
  String get playerOutroMood30;

  /// No description provided for @playerOutroMoodMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String playerOutroMoodMinutes(int minutes);

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'{years} years old'**
  String ageYears(int years);

  /// No description provided for @ageYearsMonths.
  ///
  /// In en, this message translates to:
  /// **'{years} years {months} months'**
  String ageYearsMonths(int years, int months);

  /// No description provided for @commonPleaseSelect.
  ///
  /// In en, this message translates to:
  /// **'Please select'**
  String get commonPleaseSelect;

  /// No description provided for @storiesContinueEpisodeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Continue next episode'**
  String get storiesContinueEpisodeTooltip;

  /// No description provided for @netTimeout.
  ///
  /// In en, this message translates to:
  /// **'Network timed out. Please try again later.'**
  String get netTimeout;

  /// No description provided for @netOfflineCached.
  ///
  /// In en, this message translates to:
  /// **'Network unavailable. Showing local cache.'**
  String get netOfflineCached;

  /// No description provided for @apiSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please sign in again.'**
  String get apiSessionExpired;

  /// No description provided for @apiRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh sign-in.'**
  String get apiRefreshFailed;

  /// No description provided for @apiStoryGenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'Story generation failed'**
  String get apiStoryGenerateFailed;

  /// No description provided for @apiStoryCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the story'**
  String get apiStoryCreateFailed;

  /// No description provided for @apiStoryWaitNetworkUnstable.
  ///
  /// In en, this message translates to:
  /// **'Network is unstable; generation may still be running. Refresh Stories later, or tap Continue waiting.'**
  String get apiStoryWaitNetworkUnstable;

  /// No description provided for @apiStoryWaitTimeout.
  ///
  /// In en, this message translates to:
  /// **'Network timed out; generation may still be running. Refresh later or tap Continue waiting.'**
  String get apiStoryWaitTimeout;

  /// No description provided for @apiStoryWaitOffline.
  ///
  /// In en, this message translates to:
  /// **'Network unavailable; generation may still be running. When back online, tap Continue waiting.'**
  String get apiStoryWaitOffline;

  /// No description provided for @apiStoryWaitDeadline.
  ///
  /// In en, this message translates to:
  /// **'Timed out waiting for the story. Check Stories to see if it finished.'**
  String get apiStoryWaitDeadline;

  /// No description provided for @apiNetworkUnstableRetry.
  ///
  /// In en, this message translates to:
  /// **'Network is unstable. Please try again later.'**
  String get apiNetworkUnstableRetry;

  /// No description provided for @apiForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don’t have permission for this action'**
  String get apiForbidden;

  /// No description provided for @apiNotFound.
  ///
  /// In en, this message translates to:
  /// **'Content not found'**
  String get apiNotFound;

  /// No description provided for @apiTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later.'**
  String get apiTooManyRequests;

  /// No description provided for @apiServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Service temporarily unavailable. Please try again later.'**
  String get apiServerUnavailable;

  /// No description provided for @apiRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed ({statusCode})'**
  String apiRequestFailed(int statusCode);

  /// No description provided for @bootCannotConnect.
  ///
  /// In en, this message translates to:
  /// **'Can\'t connect'**
  String get bootCannotConnect;

  /// No description provided for @bootRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get bootRetry;

  /// No description provided for @bootHintRemote.
  ///
  /// In en, this message translates to:
  /// **'For staging/online, use the Cloudflare HTTPS host:\n--dart-define=API_BASE_URL=https://bedtime-api.<your-domain>\nand register with an invite code or sign in with phone.'**
  String get bootHintRemote;

  /// No description provided for @bootHintLocal.
  ///
  /// In en, this message translates to:
  /// **'If the screen stays blank or won\'t connect: Settings → Privacy & Security → Local Network → enable this app;\nand launch with --dart-define=API_BASE_URL=http://<your-Mac-LAN-IP>:8000.'**
  String get bootHintLocal;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
