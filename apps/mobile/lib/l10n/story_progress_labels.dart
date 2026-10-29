import 'app_localizations.dart';

/// Localized story job progress (`queued`, `draft`, `tts_running`, …).
String storyProgressLabel(AppLocalizations l10n, String progress) {
  switch (progress) {
    case 'queued':
      return l10n.storyProgressQueued;
    case 'series_outline':
      return l10n.storyProgressSeriesOutline;
    case 'episode_plan':
      return l10n.storyProgressEpisodePlan;
    case 'draft':
      return l10n.storyProgressDraft;
    case 'tts':
    case 'tts_running':
      return l10n.storyProgressTts;
    case 'ready':
      return l10n.storyProgressReadyPlay;
    case 'text_ready':
      return l10n.storyNoAudioShort;
    case 'failed':
      return l10n.storyProgressFailed;
    case 'retrying':
      return l10n.storyRetrying;
    default:
      return l10n.storyProgressGenerating(progress);
  }
}
